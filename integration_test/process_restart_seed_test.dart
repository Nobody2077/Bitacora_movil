import 'dart:io';

import 'package:bitacora_rpg_personal/features/access/application/access_session_controller.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
import 'package:bitacora_rpg_personal/features/access/data/method_channel_access_credential_store.dart';
import 'package:bitacora_rpg_personal/features/access/data/pbkdf2_access_credential_hasher.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_record.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/process_restart_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelAccessCredentialStore store = processRestartStore();

  setUp(store.clearTestMaterial);

  testWidgets(
    'seed: persiste credenciales cifradas y deja una sesión desbloqueada',
    (WidgetTester tester) async {
      final Pbkdf2AccessCredentialHasher hasher = processRestartHasher();
      final AccessCredentialRecord record = await createProcessRestartRecord(
        hasher,
      );
      await store.write(record);

      final AccessCredentialRecord? persisted = await store.read();
      expect(persisted?.toJsonString(), record.toJsonString());

      final ProviderContainer container = processRestartSessionContainer(
        store: store,
        hasher: hasher,
      );
      addTearDown(container.dispose);
      container.read(accessSessionProvider);

      await waitForProcessRestartPhase(
        tester: tester,
        container: container,
        phase: AccessSessionPhase.locked,
      );
      final bool unlocked = await container
          .read(accessSessionProvider.notifier)
          .unlockWithPin(processRestartPin);

      expect(unlocked, isTrue);
      expect(
        container.read(accessSessionProvider).phase,
        AccessSessionPhase.unlocked,
      );
      expect(await store.read(), isNotNull);
    },
    skip: !Platform.isAndroid,
  );
}
