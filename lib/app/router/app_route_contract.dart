import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

enum AppArea {
  access,
  home,
  missions,
  journal,
  character,
  finance,
  dashboard,
  settings,
  navigation,
}

/// Construye la hoja de una ruta a partir de su estado.
///
/// Devolver `null` (por ejemplo, cuando falta un parámetro obligatorio o la
/// superficie aún no tiene página real) hace que el router muestre el
/// `FeaturePlaceholderPage`. El envoltorio transversal —guard de sesión y
/// observador de construcción— lo aplica el router, no cada builder.
typedef RouteContentBuilder =
    Widget? Function(BuildContext context, GoRouterState state);

class AppRouteContract {
  const AppRouteContract({
    required this.name,
    required this.path,
    required this.title,
    required this.area,
    this.queryParameters = const <String>{},
    this.isFunctionalSurface = true,
    this.builder,
  });

  final String name;
  final String path;
  final String title;
  final AppArea area;
  final Set<String> queryParameters;
  final bool isFunctionalSurface;

  /// Página asociada a la ruta. `null` indica una superficie diferida que
  /// cae deliberadamente al placeholder.
  final RouteContentBuilder? builder;
}
