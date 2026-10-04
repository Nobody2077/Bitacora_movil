import 'package:drift/drift.dart';

import '../app_database.dart';
import 'dao_support.dart';

/// Dueños de una foto cifrada única (ADR-006 D15/D16). Los objetos del
/// inventario (`item_photos`) se añaden en la fase 2.
enum PhotoOwnerKind {
  contact('contact_photos', 'contact_id', 'contacts'),
  mission('mission_photos', 'mission_id', 'missions');

  const PhotoOwnerKind(this.photoTable, this.ownerColumn, this.ownerTable);

  final String photoTable;
  final String ownerColumn;
  final String ownerTable;
}

/// Fila de `contact_photos` o `mission_photos`; las dos tablas son idénticas
/// salvo la columna del dueño.
final class EntityPhotoRow {
  const EntityPhotoRow({
    required this.id,
    required this.ownerId,
    required this.storageName,
    required this.mimeType,
    required this.byteLength,
    required this.cipherSha256,
    required this.widthPx,
    required this.heightPx,
    required this.createdAt,
    this.archivedAt,
  });

  final String id;
  final String ownerId;
  final String storageName;
  final String mimeType;
  final int byteLength;
  final String cipherSha256;
  final int widthPx;
  final int heightPx;
  final int createdAt;
  final int? archivedAt;
}

final class EntityPhotoReplacement {
  const EntityPhotoReplacement({required this.current, this.previous});

  final EntityPhotoRow current;

  /// La foto que estaba vigente y quedó archivada; su fichero se borra solo
  /// cuando el nuevo ya está confirmado.
  final EntityPhotoRow? previous;
}

/// Una foto vigente por dueño, garantizada por los índices únicos parciales
/// `uq_*_photo_current`. Cambiar la foto archiva la anterior e inserta la
/// nueva en la misma transacción.
final class EntityPhotoDao {
  EntityPhotoDao(this._database);

  final AppDatabase _database;

  static const int maxBatchIds = 400;

  Future<EntityPhotoRow?> findCurrent(PhotoOwnerKind kind, String ownerId) =>
      _database.transaction(() => _findCurrent(kind, ownerId));

  /// Foto vigente de cada dueño pedido; los que no tienen no aparecen.
  Stream<Map<String, EntityPhotoRow>> watchCurrent(
    PhotoOwnerKind kind,
    Set<String> ownerIds,
  ) {
    if (ownerIds.isEmpty) {
      return Stream<Map<String, EntityPhotoRow>>.value(
        const <String, EntityPhotoRow>{},
      );
    }
    if (ownerIds.length > maxBatchIds) {
      throw ArgumentError.value(
        ownerIds.length,
        'ownerIds',
        'At most $maxBatchIds ids per query.',
      );
    }
    final String placeholders = List<String>.filled(
      ownerIds.length,
      '?',
    ).join(', ');
    return _database
        .customSelect(
          '${_selectSql(kind)} '
          'WHERE ${kind.ownerColumn} IN ($placeholders) '
          'AND archived_at IS NULL',
          variables: ownerIds
              .map((String id) => Variable<String>(id))
              .toList(growable: false),
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _photoTable(kind),
          },
        )
        .watch()
        .map(
          (List<QueryRow> rows) =>
              Map<String, EntityPhotoRow>.unmodifiable(<String, EntityPhotoRow>{
                for (final QueryRow row in rows)
                  row.read<String>('owner_id'): _fromRow(row),
              }),
        );
  }

  /// Archiva la foto vigente (si hay) e inserta [photo] como la nueva.
  ///
  /// El dueño debe existir y no estar archivado.
  Future<EntityPhotoReplacement> replaceCurrent(
    PhotoOwnerKind kind,
    EntityPhotoRow photo,
  ) {
    if (photo.archivedAt != null) {
      throw ArgumentError('A new photo cannot be archived.');
    }
    return _database.transaction(() async {
      await _requireActiveOwner(kind, photo.ownerId);
      final EntityPhotoRow? previous = await _findCurrent(kind, photo.ownerId);
      if (previous != null) {
        await _archive(kind, previous.id, photo.createdAt);
      }
      await _database.customInsert(
        'INSERT INTO ${kind.photoTable} (id, ${kind.ownerColumn}, '
        'storage_name, mime_type, byte_length, cipher_sha256, width_px, '
        'height_px, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: <Variable<Object>>[
          Variable<String>(photo.id),
          Variable<String>(photo.ownerId),
          Variable<String>(photo.storageName),
          Variable<String>(photo.mimeType),
          Variable<int>(photo.byteLength),
          Variable<String>(photo.cipherSha256),
          Variable<int>(photo.widthPx),
          Variable<int>(photo.heightPx),
          Variable<int>(photo.createdAt),
        ],
        updates: <TableInfo<Table, dynamic>>{_photoTable(kind)},
      );
      final EntityPhotoRow? current = await _findCurrent(kind, photo.ownerId);
      if (current == null || current.id != photo.id) {
        throw RecordNotFoundException(table: kind.photoTable, key: photo.id);
      }
      return EntityPhotoReplacement(
        current: current,
        previous: previous == null ? null : await _findById(kind, previous.id),
      );
    });
  }

  /// Deshace un [replaceCurrent] cuyo fichero no pudo confirmarse: archiva la
  /// nueva y, si existía, vuelve a dejar vigente la anterior.
  Future<void> revertReplacement(
    PhotoOwnerKind kind, {
    required String newPhotoId,
    required String? previousPhotoId,
    required int archivedAtUtcMs,
  }) {
    return _database.transaction(() async {
      await _archive(kind, newPhotoId, archivedAtUtcMs);
      if (previousPhotoId != null) {
        await _database.customUpdate(
          'UPDATE ${kind.photoTable} SET archived_at = NULL WHERE id = ?',
          variables: <Variable<Object>>[Variable<String>(previousPhotoId)],
          updates: <TableInfo<Table, dynamic>>{_photoTable(kind)},
          updateKind: UpdateKind.update,
        );
      }
    });
  }

  /// Quita la foto vigente; devuelve la archivada, o `null` si no había.
  Future<EntityPhotoRow?> archiveCurrent(
    PhotoOwnerKind kind,
    String ownerId, {
    required int archivedAtUtcMs,
  }) {
    return _database.transaction(() async {
      final EntityPhotoRow? current = await _findCurrent(kind, ownerId);
      if (current == null) {
        return null;
      }
      await _archive(kind, current.id, archivedAtUtcMs);
      return _findById(kind, current.id);
    });
  }

  /// Ficheros vigentes de todos los dueños: lo que la limpieza de huérfanos
  /// del almacén `entity_photos` debe conservar.
  Future<Set<String>> findActiveStorageNames() async {
    final String sql = PhotoOwnerKind.values
        .map(
          (PhotoOwnerKind kind) =>
              'SELECT storage_name FROM ${kind.photoTable} '
              'WHERE archived_at IS NULL',
        )
        .join(' UNION ALL ');
    final List<QueryRow> rows = await _database.customSelect(sql).get();
    return rows.map((QueryRow row) => row.read<String>('storage_name')).toSet();
  }

  Future<EntityPhotoRow?> _findCurrent(
    PhotoOwnerKind kind,
    String ownerId,
  ) async {
    final QueryRow? row = await _database
        .customSelect(
          '${_selectSql(kind)} '
          'WHERE ${kind.ownerColumn} = ? AND archived_at IS NULL',
          variables: <Variable<Object>>[Variable<String>(ownerId)],
        )
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<EntityPhotoRow?> _findById(PhotoOwnerKind kind, String id) async {
    final QueryRow? row = await _database
        .customSelect(
          '${_selectSql(kind)} WHERE id = ?',
          variables: <Variable<Object>>[Variable<String>(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<void> _archive(PhotoOwnerKind kind, String id, int archivedAt) async {
    final int affected = await _database.customUpdate(
      'UPDATE ${kind.photoTable} SET archived_at = ? '
      'WHERE id = ? AND archived_at IS NULL',
      variables: <Variable<Object>>[
        Variable<int>(archivedAt),
        Variable<String>(id),
      ],
      updates: <TableInfo<Table, dynamic>>{_photoTable(kind)},
      updateKind: UpdateKind.update,
    );
    if (affected != 1) {
      throw RecordNotFoundException(table: kind.photoTable, key: id);
    }
  }

  Future<void> _requireActiveOwner(PhotoOwnerKind kind, String ownerId) async {
    final QueryRow? owner = await _database
        .customSelect(
          'SELECT archived_at FROM ${kind.ownerTable} WHERE id = ?',
          variables: <Variable<Object>>[Variable<String>(ownerId)],
        )
        .getSingleOrNull();
    if (owner == null) {
      throw RecordNotFoundException(table: kind.ownerTable, key: ownerId);
    }
    if (owner.read<int?>('archived_at') != null) {
      throw DatabaseInvariantException(
        '${kind.ownerTable}/$ownerId is archived.',
      );
    }
  }

  TableInfo<Table, dynamic> _photoTable(PhotoOwnerKind kind) => switch (kind) {
    PhotoOwnerKind.contact => _database.contactPhotos,
    PhotoOwnerKind.mission => _database.missionPhotos,
  };

  static String _selectSql(PhotoOwnerKind kind) =>
      'SELECT id, ${kind.ownerColumn} AS owner_id, storage_name, mime_type, '
      'byte_length, cipher_sha256, width_px, height_px, created_at, '
      'archived_at FROM ${kind.photoTable}';

  static EntityPhotoRow _fromRow(QueryRow row) => EntityPhotoRow(
    id: row.read<String>('id'),
    ownerId: row.read<String>('owner_id'),
    storageName: row.read<String>('storage_name'),
    mimeType: row.read<String>('mime_type'),
    byteLength: row.read<int>('byte_length'),
    cipherSha256: row.read<String>('cipher_sha256'),
    widthPx: row.read<int>('width_px'),
    heightPx: row.read<int>('height_px'),
    createdAt: row.read<int>('created_at'),
    archivedAt: row.read<int?>('archived_at'),
  );
}
