import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_preferences_provider.dart';

/// Aplica el modo de las barras del sistema. Proveedor aparte para que las
/// pruebas comprueben qué se pide sin tocar la plataforma.
final Provider<Future<void> Function(bool immersive)>
systemUiModeApplierProvider = Provider<Future<void> Function(bool immersive)>(
  (Ref ref) =>
      (bool immersive) => SystemChrome.setEnabledSystemUIMode(
        immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
);

/// Pantalla completa: oculta la barra de estado y la de navegación. Un gesto
/// desde el borde las muestra un momento y vuelven a ocultarse solas.
///
/// Android puede devolver las barras al volver de otra app; por eso el modo se
/// vuelve a aplicar al reanudar.
class ImmersiveModeBoundary extends ConsumerStatefulWidget {
  const ImmersiveModeBoundary({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ImmersiveModeBoundary> createState() =>
      _ImmersiveModeBoundaryState();
}

class _ImmersiveModeBoundaryState extends ConsumerState<ImmersiveModeBoundary>
    with WidgetsBindingObserver {
  bool? _applied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool? immersive = _applied;
    if (state == AppLifecycleState.resumed && immersive != null) {
      _apply(immersive, force: true);
    }
  }

  void _apply(bool immersive, {bool force = false}) {
    if (!force && _applied == immersive) {
      return;
    }
    _applied = immersive;
    unawaited(
      ref.read(systemUiModeApplierProvider)(immersive).catchError((_) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool? immersive = ref.watch(immersiveModeProvider).value;
    if (immersive != null) {
      _apply(immersive);
    }
    return widget.child;
  }
}
