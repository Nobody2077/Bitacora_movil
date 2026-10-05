import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/app/theme/app_ui_preferences.dart';
import 'package:bitacora_rpg_personal/features/economy/application/economy_providers.dart';
import 'package:bitacora_rpg_personal/features/economy/domain/models/economy_snapshot.dart';
import 'package:bitacora_rpg_personal/shared/adaptive/shell_chrome.dart';
import 'package:bitacora_rpg_personal/shared/adaptive/terminal_application_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    bool withShell = true,
    bool hideAmounts = false,
    VoidCallback? onToggle,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          economySnapshotProvider.overrideWith(
            (Ref ref) => Stream<EconomySnapshot>.value(
              const EconomySnapshot(
                totalMinor: 150050,
                reservedMinor: 26000,
                monthIncomeMinor: 0,
                monthExpenseMinor: 0,
                dayIncomeMinor: 0,
                dayExpenseMinor: 0,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (BuildContext context, Widget? child) =>
              AppUiPreferencesBoundary(
                preferences: AppUiPreferences(
                  largeText: false,
                  reduceMotion: false,
                  highContrast: false,
                  hideAmounts: hideAmounts,
                ),
                child: child!,
              ),
          home: Scaffold(
            body: withShell
                ? ShellChrome(
                    sidebarVisible: true,
                    onToggleSidebar: onToggle ?? () {},
                    child: const TerminalApplicationHeader(),
                  )
                : const TerminalApplicationHeader(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lleva ☰, hora y saldo, sin los textos de antes', (
    WidgetTester tester,
  ) async {
    int toggles = 0;
    await pumpHeader(tester, onToggle: () => toggles++);

    expect(find.byKey(const Key('sidebar-toggle')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('header-clock'))).data,
      matches(RegExp(r'^\d\d:\d\d$')),
    );
    expect(find.text('Bs 1240,50'), findsOneWidget);
    expect(find.textContaining('BITÁCORA RPG PERSONAL'), findsNothing);
    expect(find.textContaining('Datos locales'), findsNothing);
    expect(find.textContaining('Terminal local'), findsNothing);
    expect(find.textContaining('/2026'), findsNothing);

    await tester.tap(find.byKey(const Key('sidebar-toggle')));
    expect(toggles, 1);
  });

  testWidgets('con importes ocultos el saldo sale tapado', (
    WidgetTester tester,
  ) async {
    await pumpHeader(tester, hideAmounts: true);

    expect(find.text('Bs •••'), findsOneWidget);
    expect(find.textContaining('1240'), findsNothing);
  });

  testWidgets('sin shell de tablet no hay ☰', (WidgetTester tester) async {
    await pumpHeader(tester, withShell: false);

    expect(find.byKey(const Key('sidebar-toggle')), findsNothing);
    expect(find.byKey(const Key('header-clock')), findsOneWidget);
  });
}
