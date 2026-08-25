enum AppArea {
  access,
  home,
  missions,
  journal,
  finance,
  dashboard,
  settings,
  navigation,
}

class AppRouteContract {
  const AppRouteContract({
    required this.name,
    required this.path,
    required this.title,
    required this.area,
    this.queryParameters = const <String>{},
    this.isFunctionalSurface = true,
  });

  final String name;
  final String path;
  final String title;
  final AppArea area;
  final Set<String> queryParameters;
  final bool isFunctionalSurface;
}
