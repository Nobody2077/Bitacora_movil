import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cierra la app como el gesto «atrás» desde la raíz. Proveedor aparte para
/// que las pruebas puedan sustituirlo sin cerrar el proceso de test.
final Provider<Future<void> Function()> appExitProvider =
    Provider<Future<void> Function()>((Ref ref) => SystemNavigator.pop);
