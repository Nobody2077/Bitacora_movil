import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/shared/widgets/terminal/terminal_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('carga anuncia su estado como región viva', (
    WidgetTester tester,
  ) async {
    await _pumpState(
      tester,
      const TerminalLoadingState(message: 'Cargando datos seguros…'),
    );

    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('Cargando datos seguros…'),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error anuncia, enfoca y ejecuta reintento', (
    WidgetTester tester,
  ) async {
    var retryCount = 0;
    await _pumpState(
      tester,
      TerminalErrorState(
        title: 'Datos no disponibles',
        description: 'No fue posible leer la base local.',
        onRetry: () => retryCount += 1,
      ),
    );

    final SemanticsNode stateNode = tester.getSemantics(
      find.bySemanticsLabel(
        'Datos no disponibles. No fue posible leer la base local.',
      ),
    );
    expect(stateNode.flagsCollection.isLiveRegion, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final BuildContext? focusedContext =
        FocusManager.instance.primaryFocus?.context;
    expect(focusedContext, isNotNull);
    final Finder focusedElement = find.byElementPredicate(
      (Element value) => identical(value, focusedContext),
    );
    expect(
      find.ancestor(of: focusedElement, matching: find.byType(OutlinedButton)),
      findsOneWidget,
    );

    await tester.tap(find.text('REINTENTAR'));
    expect(retryCount, 1);
  });

  testWidgets('vacío conserva título y descripción como región viva', (
    WidgetTester tester,
  ) async {
    await _pumpState(
      tester,
      const TerminalEmptyState(
        title: 'Todavía no hay registros',
        description: 'Los nuevos elementos aparecerán en esta sección.',
      ),
    );

    final SemanticsNode stateNode = tester.getSemantics(
      find.bySemanticsLabel(
        'Todavía no hay registros. '
        'Los nuevos elementos aparecerán en esta sección.',
      ),
    );
    expect(stateNode.flagsCollection.isLiveRegion, isTrue);
    expect(find.text('Todavía no hay registros'), findsOneWidget);
    expect(
      find.text('Los nuevos elementos aparecerán en esta sección.'),
      findsOneWidget,
    );
  });

  testWidgets('estados cumplen accesibilidad con texto 2.0x', (
    WidgetTester tester,
  ) async {
    await _pumpState(
      tester,
      TerminalErrorState(
        title: 'Sin conexión local',
        description: 'Vuelve a intentar la operación protegida.',
        onRetry: () {},
      ),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('página de estado se adapta en compacto con texto 2.0x', (
    WidgetTester tester,
  ) async {
    await _pumpState(
      tester,
      TerminalAsyncStatePage(
        child: TerminalErrorState(
          title: 'Formulario no disponible',
          description: 'No se pudieron preparar los datos locales.',
          onRetry: () {},
        ),
      ),
      size: const Size(320, 568),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Formulario no disponible'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
  });

  testWidgets('estado de carga en línea anuncia la operación', (
    WidgetTester tester,
  ) async {
    await _pumpState(
      tester,
      const TerminalInlineLoadingState(
        message: 'Cargando fotografías privadas…',
      ),
    );

    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('Cargando fotografías privadas…'),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('error en línea anuncia y permite reintentar', (
    WidgetTester tester,
  ) async {
    var retryCount = 0;
    await _pumpState(
      tester,
      TerminalInlineErrorState(
        message: 'No se pudieron cargar las opciones.',
        onRetry: () => retryCount += 1,
      ),
      textScale: 2,
    );

    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('No se pudieron cargar las opciones.'),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    await tester.tap(find.text('REINTENTAR'));
    expect(retryCount, 1);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpState(
  WidgetTester tester,
  Widget state, {
  Size size = const Size(412, 915),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Padding(padding: const EdgeInsets.all(16), child: state),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
