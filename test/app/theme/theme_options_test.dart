import 'dart:math' as math;

import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme_tokens.dart';
import 'package:bitacora_rpg_personal/app/theme/terminal_backdrop.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/settings/data/drift_settings_repository.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/models/app_preferences.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/settings_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contraste WCAG entre dos colores opacos.
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('contraste del texto (mínimo 4,5:1)', () {
    // El punto más claro del degradado Vino y un panel encima de él.
    const Color wineTop = TerminalBackdropTheme.wineTop;
    final Color winePanel = Color.alphaBlend(AppThemeTokens.winePanel, wineTop);
    final Map<String, Color> backgrounds = <String, Color>{
      'negro': Colors.black,
      'vino': wineTop,
      'panel sobre vino': winePanel,
    };
    final AppThemeTokens tokens = AppThemeTokens.terminal;
    final Map<String, Color> texts = <String, Color>{
      'blanco': tokens.textPrimary,
      'cian': tokens.infoCyan,
      'gris secundario': tokens.textSecondary,
      'rojo': tokens.terminalRed,
      'amarillo': tokens.valueYellow,
      'verde': tokens.progressGreen,
      'naranja': tokens.attentionOrange,
    };

    for (final MapEntry<String, Color> background in backgrounds.entries) {
      for (final MapEntry<String, Color> text in texts.entries) {
        test('${text.key} sobre ${background.key}', () {
          expect(
            _contrast(text.value, background.value),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    }
  });

  group('tokens según Apariencia', () {
    test('por defecto, negro y texto blanco', () {
      expect(AppThemeTokens.resolve(), same(AppThemeTokens.terminal));
    });

    test('Cian cambia solo el texto principal', () {
      final AppThemeTokens tokens = AppThemeTokens.resolve(cyanText: true);

      expect(tokens.textPrimary, AppThemeTokens.terminal.infoCyan);
      expect(tokens.textSecondary, AppThemeTokens.terminal.textSecondary);
      expect(tokens.valueYellow, AppThemeTokens.terminal.valueYellow);
      expect(tokens.surfaceLow, AppThemeTokens.terminal.surfaceLow);
    });

    test('Vino deja los paneles semitransparentes y no toca el texto', () {
      final AppThemeTokens tokens = AppThemeTokens.resolve(wine: true);

      expect(tokens.surfaceLow, AppThemeTokens.winePanel);
      expect(tokens.surfaceHigh, AppThemeTokens.winePanel);
      expect(tokens.surfaceOverlay, Colors.black);
      expect(tokens.textPrimary, AppThemeTokens.terminal.textPrimary);
    });

    test('alto contraste anula Vino y Cian', () {
      expect(
        AppThemeTokens.resolve(highContrast: true, wine: true, cyanText: true),
        same(AppThemeTokens.terminalHighContrast),
      );
      final ThemeData theme = AppTheme.dark(
        highContrast: true,
        wine: true,
        cyanText: true,
      );
      expect(theme.extension<TerminalBackdropTheme>()!.wine, isFalse);
      expect(theme.scaffoldBackgroundColor, Colors.black);
    });

    test('en Vino las páginas son transparentes y los diálogos opacos', () {
      final ThemeData theme = AppTheme.dark(wine: true);

      expect(theme.extension<TerminalBackdropTheme>()!.wine, isTrue);
      expect(theme.scaffoldBackgroundColor, Colors.transparent);
      expect(theme.dialogTheme.backgroundColor, Colors.black);
      expect(theme.drawerTheme.backgroundColor, Colors.black);
      expect(theme.colorScheme.surface, Colors.black);
    });

    test('con texto Cian, el texto del tema es cian', () {
      final ThemeData theme = AppTheme.dark(cyanText: true);

      expect(
        theme.textTheme.bodyMedium?.color,
        AppThemeTokens.terminal.infoCyan,
      );
    });
  });

  group('fondo', () {
    Future<void> pumpBackdrop(
      WidgetTester tester, {
      required bool wine,
      bool reduceMotion = false,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(wine: wine),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const TerminalBackdrop(child: Text('contenido')),
        ),
      ),
    );

    testWidgets('Negro pinta negro liso', (WidgetTester tester) async {
      await pumpBackdrop(tester, wine: false);

      expect(find.byKey(const Key('backdrop-black')), findsOneWidget);
      expect(find.byKey(const Key('backdrop-wine')), findsNothing);
    });

    testWidgets('Vino pinta el degradado con líneas de barrido', (
      WidgetTester tester,
    ) async {
      await pumpBackdrop(tester, wine: true);

      expect(find.byKey(const Key('backdrop-wine')), findsOneWidget);
      expect(find.byKey(const Key('backdrop-scanlines')), findsOneWidget);
      expect(find.text('contenido'), findsOneWidget);
    });

    testWidgets('con movimiento reducido, Vino sin líneas', (
      WidgetTester tester,
    ) async {
      await pumpBackdrop(tester, wine: true, reduceMotion: true);

      expect(find.byKey(const Key('backdrop-wine')), findsOneWidget);
      expect(find.byKey(const Key('backdrop-scanlines')), findsNothing);
    });
  });

  test('fondo y color del texto se guardan cifrados y se recuperan', () async {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final DriftSettingsRepository repository = DriftSettingsRepository(
      SettingsDao(database),
    );
    final AppPreferences loaded = (await repository.load()).fold(
      onSuccess: (AppPreferences value) => value,
      onFailure: (failure) => throw failure,
    );
    expect(loaded.wineBackground, isFalse);
    expect(loaded.cyanText, isFalse);

    final Result<void> saved = await repository.save(
      loaded.copyWith(
        themeKey: AppPreferences.wineThemeKey,
        cyanText: true,
        updatedAtUtc: DateTime.utc(2026, 10, 5),
      ),
    );
    expect(saved, isA<Success<void>>());

    final AppPreferences reloaded = (await repository.load()).fold(
      onSuccess: (AppPreferences value) => value,
      onFailure: (failure) => throw failure,
    );
    expect(reloaded.wineBackground, isTrue);
    expect(reloaded.cyanText, isTrue);
  });
}
