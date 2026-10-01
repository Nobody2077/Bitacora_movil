import 'package:bitacora_rpg_personal/app/providers/access_dependencies.dart';
import 'package:bitacora_rpg_personal/features/access/data/sensitive_clipboard.dart';
import 'package:bitacora_rpg_personal/features/access/presentation/access_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const String _code = 'ABCD-EFGH-JKMN-PQRS-TVWX-YZ01-2345-6789';

final class _FakeClipboard implements SensitiveClipboard {
  _FakeClipboard({this.content});

  String? content;
  final List<String> copied = <String>[];

  @override
  Future<void> copy(String text) async {
    copied.add(text);
    content = text;
  }

  @override
  Future<String?> readText() async => content;
}

Widget _host(_FakeClipboard clipboard, Widget child) => ProviderScope(
  overrides: [sensitiveClipboardProvider.overrideWithValue(clipboard)],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sanitizeRecoveryCodeInput', () {
    test('pasa a mayúsculas, quita lo ajeno al alfabeto y limita a 39', () {
      expect(sanitizeRecoveryCodeInput('  abcd-efgh\n'), 'ABCD-EFGH');
      expect(sanitizeRecoveryCodeInput('código: ab#cd'), 'CDIGO ABCD');
      expect(sanitizeRecoveryCodeInput('${_code}EXTRA'), _code);
    });
  });

  group('MethodChannelSensitiveClipboard', () {
    const MethodChannel channel = MethodChannel('test/sensitive_clipboard');
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            return call.method == 'clearIfMatches' ? true : null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('copia marcado como sensible y borra solo pasado el plazo', (
      WidgetTester tester,
    ) async {
      final MethodChannelSensitiveClipboard clipboard =
          MethodChannelSensitiveClipboard(channel: channel);
      await clipboard.copy(_code);
      expect(calls.single.method, 'copySensitive');
      expect(calls.single.arguments, <String, Object?>{'text': _code});

      await tester.pump(const Duration(seconds: 59));
      expect(calls, hasLength(1));

      await tester.pump(const Duration(seconds: 1));
      expect(calls, hasLength(2));
      expect(calls.last.method, 'clearIfMatches');
      expect(calls.last.arguments, <String, Object?>{'text': _code});
    });

    testWidgets('una copia nueva reinicia el plazo y solo borra la última', (
      WidgetTester tester,
    ) async {
      final MethodChannelSensitiveClipboard clipboard =
          MethodChannelSensitiveClipboard(channel: channel);
      await clipboard.copy('PRIMERO');
      await tester.pump(const Duration(seconds: 30));
      await clipboard.copy(_code);
      await tester.pump(const Duration(seconds: 59));
      expect(
        calls.where((MethodCall c) => c.method == 'clearIfMatches'),
        isEmpty,
      );

      await tester.pump(const Duration(seconds: 1));
      final List<MethodCall> clears = calls
          .where((MethodCall c) => c.method == 'clearIfMatches')
          .toList();
      expect(clears, hasLength(1));
      expect(clears.single.arguments, <String, Object?>{'text': _code});
    });
  });

  testWidgets('el código de un solo uso se copia y lo anuncia', (
    WidgetTester tester,
  ) async {
    final _FakeClipboard clipboard = _FakeClipboard();
    await tester.pumpWidget(
      _host(clipboard, const OneTimeRecoveryCode(code: _code)),
    );

    await tester.tap(find.byKey(const Key('copy-recovery-code')));
    await tester.pump();

    expect(clipboard.copied, <String>[_code]);
    expect(find.textContaining('60 segundos'), findsOneWidget);
  });

  testWidgets('pegar rellena el campo con el código saneado', (
    WidgetTester tester,
  ) async {
    final _FakeClipboard clipboard = _FakeClipboard(
      content: ' ${_code.toLowerCase()}\n',
    );
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        clipboard,
        RecoveryCodeField(
          fieldKey: const Key('recovery-code'),
          controller: controller,
          label: 'Código de recuperación',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('recovery-code-paste')));
    await tester.pump();

    expect(controller.text, _code);
    expect(controller.selection.baseOffset, _code.length);
  });

  testWidgets('pegar con el portapapeles vacío avisa y no toca el campo', (
    WidgetTester tester,
  ) async {
    final _FakeClipboard clipboard = _FakeClipboard();
    final TextEditingController controller = TextEditingController(
      text: 'ABCD',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        clipboard,
        RecoveryCodeField(
          fieldKey: const Key('recovery-code'),
          controller: controller,
          label: 'Código de recuperación',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('recovery-code-paste')));
    await tester.pump();

    expect(controller.text, 'ABCD');
    expect(find.text('No hay un código para pegar.'), findsOneWidget);
  });

  testWidgets('el botón de pegar se desactiva con el campo desactivado', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        _FakeClipboard(content: _code),
        RecoveryCodeField(
          fieldKey: const Key('recovery-code'),
          controller: controller,
          label: 'Código de recuperación',
          enabled: false,
        ),
      ),
    );

    final IconButton paste = tester.widget<IconButton>(
      find.byKey(const Key('recovery-code-paste')),
    );
    expect(paste.onPressed, isNull);
  });
}
