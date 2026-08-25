import 'app_route_contract.dart';
import 'app_routes.dart';

/// A validated, in-memory destination captured while access is locked.
///
/// The location never contains a query or fragment. Its diagnostic
/// representation deliberately redacts the path because route parameters may
/// identify private records.
final class PendingDestination {
  const PendingDestination({required this.navId, required this.location});

  final String navId;
  final String location;

  @override
  String toString() =>
      'PendingDestination(navId: $navId, location: <redacted>)';
}

/// Validates locations exclusively against the internal navigation catalog.
abstract final class PendingDestinationCatalog {
  static PendingDestination? fromLocation(String location) {
    final Uri? uri = Uri.tryParse(location);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !uri.path.startsWith('/') ||
        uri.path.startsWith('//')) {
      return null;
    }

    final String path = uri.path == '/' ? AppRoutes.home : uri.path;
    for (final AppRouteContract contract in AppRoutes.all) {
      if (contract.area == AppArea.access) {
        continue;
      }
      if (_matches(contract.path, path)) {
        return PendingDestination(navId: contract.name, location: path);
      }
    }
    return null;
  }

  static bool _matches(String pattern, String candidate) {
    final List<String> expected = Uri.parse(pattern).pathSegments;
    final List<String> actual = Uri.parse(candidate).pathSegments;
    if (expected.length != actual.length) {
      return false;
    }

    for (var index = 0; index < expected.length; index += 1) {
      final String expectedSegment = expected[index];
      final String actualSegment = actual[index];
      if (actualSegment.isEmpty ||
          actualSegment == '.' ||
          actualSegment == '..' ||
          actualSegment.contains('/') ||
          actualSegment.contains('\u0000')) {
        return false;
      }
      if (!expectedSegment.startsWith(':') &&
          expectedSegment != actualSegment) {
        return false;
      }
    }
    return true;
  }
}
