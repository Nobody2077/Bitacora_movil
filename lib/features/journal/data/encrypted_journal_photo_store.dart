import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;

import '../../../infrastructure/security/database_key_store.dart';
import '../domain/models/journal_photo.dart';

typedef JournalPhotoDirectoryLocator = Future<Directory> Function();

final class EncryptedJournalPhotoStore implements JournalPhotoStore {
  EncryptedJournalPhotoStore({
    required DatabaseKeyStore keyStore,
    required JournalPhotoDirectoryLocator directoryLocator,
    Random? random,
  }) : _keyStore = keyStore,
       _directoryLocator = directoryLocator,
       _random = random ?? Random.secure();

  static const String storageId = 'journal_attachments';
  static const String _mimeType = 'image/jpeg';
  static const int _version = 1;
  static const int _maxDimension = 4096;
  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static const List<int> _magic = <int>[0x42, 0x52, 0x50, 0x41];
  static final RegExp _storageNamePattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.brpa$',
  );

  final DatabaseKeyStore _keyStore;
  final JournalPhotoDirectoryLocator _directoryLocator;
  final Random _random;
  final AesGcm _cipher = AesGcm.with256bits(nonceLength: _nonceLength);
  final Sha256 _sha256 = Sha256();

  @override
  Future<PreparedJournalPhoto> importPhoto(String sourcePath) async {
    final String normalizedPath = sourcePath.trim();
    if (normalizedPath.isEmpty) {
      throw const JournalPhotoStoreException('PHOTO_SOURCE_INVALID');
    }
    final File source = File(normalizedPath);
    if (!await source.exists()) {
      throw const JournalPhotoStoreException('PHOTO_SOURCE_MISSING');
    }

    final Uint8List sourceBytes = await source.readAsBytes();
    final _SanitizedPhoto sanitized;
    try {
      sanitized = await Isolate.run(
        () => _sanitizePhoto(sourceBytes, _maxDimension),
      );
    } on Object {
      throw const JournalPhotoStoreException('PHOTO_DECODE_FAILED');
    } finally {
      sourceBytes.fillRange(0, sourceBytes.length, 0);
    }

    final Directory directory = await _directory();
    final bool encryptedFilesExist = await _hasEncryptedFiles(directory);
    final SecretKey secretKey = await _secretKey(
      encryptedFilesExist: encryptedFilesExist,
    );
    final List<int> nonce = List<int>.generate(
      _nonceLength,
      (_) => _random.nextInt(256),
      growable: false,
    );
    final SecretBox secretBox;
    try {
      secretBox = await _cipher.encrypt(
        sanitized.bytes,
        secretKey: secretKey,
        nonce: nonce,
      );
    } finally {
      sanitized.bytes.fillRange(0, sanitized.bytes.length, 0);
    }

    final Uint8List encrypted = Uint8List(
      _magic.length + 1 + secretBox.concatenation().length,
    );
    encrypted.setAll(0, _magic);
    encrypted[_magic.length] = _version;
    encrypted.setAll(_magic.length + 1, secretBox.concatenation());
    final String hash = _hex((await _sha256.hash(encrypted)).bytes);
    final String storageName = '${_uuidV4()}.brpa';
    final File temporary = File(p.join(directory.path, '$storageName.tmp'));
    final File destination = File(p.join(directory.path, storageName));

    try {
      await temporary.writeAsBytes(encrypted, flush: true);
      if (await destination.exists()) {
        throw const JournalPhotoStoreException('PHOTO_NAME_COLLISION');
      }
    } on Object catch (error) {
      await _deleteBestEffort(temporary);
      await _deleteBestEffort(destination);
      if (error is JournalPhotoStoreException) {
        rethrow;
      }
      throw const JournalPhotoStoreException('PHOTO_WRITE_FAILED');
    }

    return PreparedJournalPhoto(
      storageName: storageName,
      mimeType: _mimeType,
      byteLength: encrypted.length,
      cipherSha256: hash,
      widthPx: sanitized.width,
      heightPx: sanitized.height,
    );
  }

  @override
  Future<void> commitPhoto(String storageName) async {
    _validateStorageName(storageName);
    final Directory directory = await _directory();
    final File temporary = File(p.join(directory.path, '$storageName.tmp'));
    final File destination = File(p.join(directory.path, storageName));
    if (await destination.exists()) {
      if (await temporary.exists()) {
        await _deleteBestEffort(temporary);
      }
      return;
    }
    if (!await temporary.exists()) {
      throw const JournalPhotoStoreException('PHOTO_TEMPORARY_MISSING');
    }
    try {
      await temporary.rename(destination.path);
    } on Object {
      throw const JournalPhotoStoreException('PHOTO_COMMIT_FAILED');
    }
  }

  @override
  Future<Uint8List> readPhoto(JournalPhoto photo) async {
    _validateStorageName(photo.storageName);
    final Directory directory = await _directory();
    final File file = File(p.join(directory.path, photo.storageName));
    if (!await file.exists()) {
      throw const JournalPhotoStoreException('PHOTO_FILE_MISSING');
    }
    final Uint8List encrypted = await file.readAsBytes();
    if (encrypted.length != photo.byteLength ||
        _hex((await _sha256.hash(encrypted)).bytes) != photo.cipherSha256) {
      throw const JournalPhotoStoreException('PHOTO_INTEGRITY_FAILED');
    }
    if (encrypted.length <= _magic.length + 1 + _nonceLength + _macLength ||
        !_startsWithMagic(encrypted) ||
        encrypted[_magic.length] != _version) {
      throw const JournalPhotoStoreException('PHOTO_FORMAT_INVALID');
    }

    final SecretBox box = SecretBox.fromConcatenation(
      encrypted.sublist(_magic.length + 1),
      nonceLength: _nonceLength,
      macLength: _macLength,
      copy: false,
    );
    try {
      final List<int> clear = await _cipher.decrypt(
        box,
        secretKey: await _secretKey(encryptedFilesExist: true),
      );
      return Uint8List.fromList(clear);
    } on Object {
      throw const JournalPhotoStoreException('PHOTO_DECRYPT_FAILED');
    }
  }

  @override
  Future<void> deletePhoto(String storageName) async {
    _validateStorageName(storageName);
    final Directory directory = await _directory();
    await _deleteBestEffort(File(p.join(directory.path, storageName)));
    await _deleteBestEffort(File(p.join(directory.path, '$storageName.tmp')));
  }

  @override
  Future<int> cleanOrphans(Set<String> activeStorageNames) async {
    for (final String name in activeStorageNames) {
      _validateStorageName(name);
    }
    final Directory directory = await _directory();
    int removed = 0;
    for (final String activeName in activeStorageNames) {
      final File destination = File(p.join(directory.path, activeName));
      final File temporary = File(p.join(directory.path, '$activeName.tmp'));
      if (!await destination.exists() && await temporary.exists()) {
        try {
          await temporary.rename(destination.path);
        } on Object {
          // Se conserva el temporal autenticado para reintentar en otro arranque.
        }
      }
    }
    await for (final FileSystemEntity entity in directory.list(
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final String name = p.basename(entity.path);
      final bool isTemporary =
          name.endsWith('.brpa.tmp') &&
          !activeStorageNames.contains(name.substring(0, name.length - 4));
      final bool isOrphan =
          _storageNamePattern.hasMatch(name) &&
          !activeStorageNames.contains(name);
      if (isTemporary || isOrphan) {
        try {
          await entity.delete();
          removed++;
        } on Object {
          // Un archivo cifrado huérfano no expone texto plano; se reintenta.
        }
      }
    }
    return removed;
  }

  Future<Directory> _directory() async {
    final Directory support = await _directoryLocator();
    final Directory directory = Directory(
      p.join(support.path, 'journal_attachments'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<SecretKey> _secretKey({required bool encryptedFilesExist}) async {
    try {
      final String hex = await _keyStore.getOrCreateDatabaseKey(
        databaseExists: encryptedFilesExist,
        storageId: storageId,
      );
      return SecretKey(_decodeHex(hex));
    } on DatabaseKeyStoreException catch (error) {
      throw JournalPhotoStoreException(error.code);
    }
  }

  Future<bool> _hasEncryptedFiles(Directory directory) async {
    await for (final FileSystemEntity entity in directory.list(
      followLinks: false,
    )) {
      if (entity is File &&
          _storageNamePattern.hasMatch(p.basename(entity.path))) {
        return true;
      }
    }
    return false;
  }

  String _uuidV4() {
    final List<int> bytes = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
      growable: false,
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final String hex = _hex(bytes);
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static void _validateStorageName(String storageName) {
    if (!_storageNamePattern.hasMatch(storageName)) {
      throw const JournalPhotoStoreException('PHOTO_STORAGE_NAME_INVALID');
    }
  }

  static bool _startsWithMagic(Uint8List bytes) {
    for (int index = 0; index < _magic.length; index++) {
      if (bytes[index] != _magic[index]) {
        return false;
      }
    }
    return true;
  }

  static List<int> _decodeHex(String value) => List<int>.generate(
    value.length ~/ 2,
    (int index) =>
        int.parse(value.substring(index * 2, index * 2 + 2), radix: 16),
    growable: false,
  );

  static String _hex(List<int> bytes) =>
      bytes.map((int value) => value.toRadixString(16).padLeft(2, '0')).join();

  static Future<void> _deleteBestEffort(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // La fila cifrada sigue siendo la autoridad; la limpieza se reintenta.
    }
  }
}

final class JournalPhotoStoreException implements Exception {
  const JournalPhotoStoreException(this.code);

  final String code;

  @override
  String toString() => 'JournalPhotoStoreException($code)';
}

final class _SanitizedPhoto {
  const _SanitizedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

_SanitizedPhoto _sanitizePhoto(Uint8List source, int maxDimension) {
  final image.Image? decoded = image.decodeImage(source);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    throw const FormatException('Unsupported image.');
  }
  image.Image normalized = image.bakeOrientation(decoded);
  if (normalized.width > maxDimension || normalized.height > maxDimension) {
    normalized = normalized.width >= normalized.height
        ? image.copyResize(
            normalized,
            width: maxDimension,
            interpolation: image.Interpolation.average,
          )
        : image.copyResize(
            normalized,
            height: maxDimension,
            interpolation: image.Interpolation.average,
          );
  }
  final Uint8List encoded = image.encodeJpg(normalized, quality: 90);
  return _SanitizedPhoto(
    bytes: encoded,
    width: normalized.width,
    height: normalized.height,
  );
}
