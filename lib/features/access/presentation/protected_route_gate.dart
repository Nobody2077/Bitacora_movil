import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/access_session_controller.dart';
import '../application/access_session_state.dart';

typedef ProtectedWidgetBuilder = Widget Function(BuildContext context);

/// Defense in depth: [builder] is never invoked while access is closed.
class ProtectedRouteGate extends ConsumerWidget {
  const ProtectedRouteGate({required this.builder, super.key});

  final ProtectedWidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool accessGranted = ref.watch(
      accessSessionProvider.select(
        (AccessSessionState session) => session.canBuildProtected,
      ),
    );
    if (!accessGranted) {
      return const SizedBox.shrink(key: Key('protected-route-blocked'));
    }
    return builder(context);
  }
}
