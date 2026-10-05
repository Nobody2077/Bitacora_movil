import 'package:bitacora_rpg_personal/app/router/app_route_contract.dart';
import 'package:bitacora_rpg_personal/app/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRoutes', () {
    test('registra los 64 patrones URI canónicos', () {
      expect(AppRoutes.all, hasLength(64));
      expect(
        AppRoutes.all.where(
          (AppRouteContract route) => route.isFunctionalSurface,
        ),
        hasLength(63),
      );
    });

    test('no repite nombres ni rutas', () {
      final Set<String> names = AppRoutes.all
          .map((AppRouteContract route) => route.name)
          .toSet();
      final Set<String> paths = AppRoutes.all
          .map((AppRouteContract route) => route.path)
          .toSet();

      expect(names, hasLength(AppRoutes.all.length));
      expect(paths, hasLength(AppRoutes.all.length));
    });

    test('separa patrones de ruta y parámetros de consulta', () {
      for (final AppRouteContract route in AppRoutes.all) {
        expect(route.path, startsWith('/'));
        expect(route.path, isNot(contains('?')));
        expect(route.path, isNot(endsWith('/')));
      }

      expect(
        _byName('missionNew').queryParameters,
        containsAll(<String>['origin', 'date', 'board']),
      );
      expect(_byName('missionsBoard').path, AppRoutes.missionsBoard);
      expect(_byName('missionsCalendar').queryParameters, contains('date'));
      expect(
        _byName('financeNewIncome').queryParameters,
        containsAll(<String>['missionId', 'refundOf']),
      );
    });

    test(
      'toda superficie funcional resuelve una página salvo las diferidas',
      () {
        final Set<String> sinBuilder = AppRoutes.all
            .where(
              (AppRouteContract route) =>
                  route.isFunctionalSurface && route.builder == null,
            )
            .map((AppRouteContract route) => route.name)
            .toSet();

        // Conjunto cerrado de superficies aún sin página real: caen al
        // placeholder de forma deliberada. Añadir una ruta sin builder obliga a
        // reconocerla aquí, evitando huérfanos silenciosos.
        expect(sinBuilder, <String>{
          'missionReschedule',
          'missionConfirmResolution',
          'settingsMissionsProgress',
          'settingsFinance',
          'settingsJournal',
          'settingsDashboard',
          'settingsAdvanced',
        });
      },
    );

    test('el contenedor de navegación /more tiene página', () {
      final AppRouteContract more = _byName('more');
      expect(more.isFunctionalSurface, isFalse);
      expect(more.builder, isNotNull);
    });

    test('conserva las seis raíces de dominio', () {
      expect(<String>{
        AppRoutes.home,
        AppRoutes.missionsToday,
        AppRoutes.journal,
        AppRoutes.finance,
        AppRoutes.dashboardDaily,
        AppRoutes.settings,
      }, hasLength(6));
    });
  });
}

AppRouteContract _byName(String name) =>
    AppRoutes.all.singleWhere((AppRouteContract route) => route.name == name);
