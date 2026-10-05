import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/persistence_providers.dart';
import '../../infrastructure/database/daos/settings_dao.dart';

/// Dónde se recuerda si la barra lateral de la tablet está visible.
abstract interface class SidebarVisibilityStore {
  Future<bool> read();

  Future<void> write(bool visible);
}

/// En los metadatos de la base cifrada, como las demás preferencias: el
/// shell solo existe con la app desbloqueada (ADR-006 D13, sin esquema).
final class SettingsSidebarVisibilityStore implements SidebarVisibilityStore {
  const SettingsSidebarVisibilityStore(this._settingsDao);

  static const String metadataKey = 'preference.sidebar_visible';

  final SettingsDao _settingsDao;

  @override
  Future<bool> read() async =>
      await _settingsDao.getMetadata(metadataKey) != '0';

  @override
  Future<void> write(bool visible) => _settingsDao.putMetadata(
    key: metadataKey,
    value: visible ? '1' : '0',
    updatedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
  );
}

final Provider<SidebarVisibilityStore> sidebarVisibilityStoreProvider =
    Provider<SidebarVisibilityStore>(
      (Ref ref) =>
          SettingsSidebarVisibilityStore(ref.watch(settingsDaoProvider)),
    );

final NotifierProvider<SidebarVisibilityController, bool>
sidebarVisibleProvider = NotifierProvider<SidebarVisibilityController, bool>(
  SidebarVisibilityController.new,
);

/// Visible por defecto; lee la preferencia guardada al empezar y la guarda
/// en cada cambio.
class SidebarVisibilityController extends Notifier<bool> {
  bool _changedByUser = false;

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    try {
      final bool stored = await ref.read(sidebarVisibilityStoreProvider).read();
      // Si el usuario ya pulsó ☰ mientras se leía, manda su pulsación.
      if (ref.mounted && !_changedByUser) state = stored;
    } on Object {
      // Sin preferencia legible, la barra se queda visible.
    }
  }

  Future<void> toggle() async {
    _changedByUser = true;
    state = !state;
    try {
      await ref.read(sidebarVisibilityStoreProvider).write(state);
    } on Object {
      // Si no se pudo guardar, el cambio vale para esta sesión.
    }
  }
}
