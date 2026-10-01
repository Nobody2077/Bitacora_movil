import '../../../shared/sound/ui_sound.dart';
import 'access_session_state.dart';

enum AccessSoundAction { play, stop }

final class AccessSoundCommand {
  const AccessSoundCommand(this.action, this.sound);

  final AccessSoundAction action;
  final UiSound sound;

  @override
  bool operator ==(Object other) =>
      other is AccessSoundCommand &&
      other.action == action &&
      other.sound == sound;

  @override
  int get hashCode => Object.hash(action, sound);

  @override
  String toString() => 'AccessSoundCommand($action, $sound)';
}

/// Qué efectos provoca un cambio de la sesión de acceso.
///
/// - Entrar en validación arranca la carga de la terminal; salir la corta,
///   para que el sonido nunca alargue la entrada.
/// - Abrirse la sesión suena una sola vez (acceso concedido).
/// - Un PIN rechazado suena como error. Solo dice lo que la pantalla ya
///   muestra: que falló, nunca qué dígito.
List<AccessSoundCommand> accessSoundCommands(
  AccessSessionState? previous,
  AccessSessionState next,
) {
  final AccessSessionPhase? was = previous?.phase;
  final AccessSessionPhase now = next.phase;
  final List<AccessSoundCommand> commands = <AccessSoundCommand>[];
  if (was == AccessSessionPhase.authenticating &&
      now != AccessSessionPhase.authenticating) {
    commands.add(
      const AccessSoundCommand(AccessSoundAction.stop, UiSound.accessLoading),
    );
  }
  if (now == AccessSessionPhase.authenticating &&
      was != AccessSessionPhase.authenticating) {
    commands.add(
      const AccessSoundCommand(AccessSoundAction.play, UiSound.accessLoading),
    );
  }
  if (now == AccessSessionPhase.unlocked &&
      was != AccessSessionPhase.unlocked) {
    commands.add(
      const AccessSoundCommand(AccessSoundAction.play, UiSound.accessGranted),
    );
  }
  if (was == AccessSessionPhase.authenticating &&
      now == AccessSessionPhase.locked &&
      (next.notice == AccessNotice.invalidCredential ||
          next.notice == AccessNotice.progressiveWait)) {
    commands.add(
      const AccessSoundCommand(AccessSoundAction.play, UiSound.accessDenied),
    );
  }
  return commands;
}
