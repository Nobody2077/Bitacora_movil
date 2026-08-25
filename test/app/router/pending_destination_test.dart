import 'package:bitacora_rpg_personal/app/router/app_routes.dart';
import 'package:bitacora_rpg_personal/app/router/pending_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PendingDestinationCatalog', () {
    test('acepta una ruta interna y elimina query y fragmento', () {
      final PendingDestination? destination =
          PendingDestinationCatalog.fromLocation(
            '/missions/mission-42/edit?returnTo=https://evil.test#secret',
          );

      expect(destination?.navId, 'missionEdit');
      expect(destination?.location, '/missions/mission-42/edit');
      expect(destination.toString(), contains('location: <redacted>'));
      expect(destination.toString(), isNot(contains('mission-42')));
    });

    test('normaliza la raíz interna a Inicio', () {
      final PendingDestination? destination =
          PendingDestinationCatalog.fromLocation('/');

      expect(destination?.navId, 'home');
      expect(destination?.location, AppRoutes.home);
    });

    test('rechaza destinos externos, públicos o fuera del catálogo', () {
      expect(
        PendingDestinationCatalog.fromLocation('https://evil.test/home'),
        isNull,
      );
      expect(
        PendingDestinationCatalog.fromLocation('//evil.test/home'),
        isNull,
      );
      expect(PendingDestinationCatalog.fromLocation(AppRoutes.lock), isNull);
      expect(PendingDestinationCatalog.fromLocation('/unknown'), isNull);
      expect(
        PendingDestinationCatalog.fromLocation('/missions/a%2Fb/edit'),
        isNull,
      );
    });

    test('prefiere superficies estáticas frente a parámetros dinámicos', () {
      final PendingDestination? destination =
          PendingDestinationCatalog.fromLocation('/missions/new');

      expect(destination?.navId, 'missionNew');
    });
  });
}
