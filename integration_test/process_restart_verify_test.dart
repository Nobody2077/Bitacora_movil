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

  tearDown(store.clearTestMaterial);

  testWidgets(
    'verify: el proceso frío conserva credenciales pero no la sesión abierta',
    (WidgetTester tester) async {
      final AccessCredentialRecord? persisted = await store.read();
      expect(
        persisted,
        isNotNull,
        reason: 'Seed material must survive the Android process restart.',
      );
      expect(
        persisted!.pinSalt,
        orderedEquals(List<int>.generate(16, (int index) => index + 1)),
      );
      expect(persisted.pinVerifier, hasLength(32));

      final Pbkdf2AccessCredentialHasher hasher = processRestartHasher();
      final ProviderContainer container = processRestartSessionContainer(
        store: store,
        hasher: hasher,
      );
      addTearDown(container.dispose);
      container.read(accessSessionProvider);

      final AccessSessionState coldState = await waitForProcessRestartPhase(
        tester: tester,
        container: container,
        phase: AccessSessionPhase.locked,
      );
      expect(coldState.canBuildProtected, isFalse);
      expect(coldState.phase, isNot(AccessSessionPhase.unlocked));

      final bool canStillUnlock = await container
          .read(accessSessionProvider.notifier)
          .unlockWithPin(processRestartPin);
      expect(canStillUnlock, isTrue);

      await store.clearTestMaterial();
      expect(await store.read(), isNull);
    },
    skip: !Platform.isAndroid,
  );
}
