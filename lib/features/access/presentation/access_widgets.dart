import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/access_session_state.dart';

class AccessScaffold extends StatelessWidget {
  const AccessScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.leading,
    this.accentColor,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens =
        Theme.of(context).extension<AppThemeTokens>() ??
        AppThemeTokens.terminal;
    final Color accent = accentColor ?? tokens.infoCyan;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    Align(alignment: Alignment.centerLeft, child: leading),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accent),
                        ),
                        child: Icon(Icons.shield_outlined, color: accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'BITÁCORA // ACCESO',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: accent,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: accent),
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: tokens.surfaceLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accentColor == null ? tokens.border : accent,
                      ),
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum AccessTerminalStage { validating, opening }

class AccessTerminalTransition extends StatefulWidget {
  const AccessTerminalTransition({
    required this.accentColor,
    required this.stage,
    super.key,
  });

  final Color accentColor;
  final AccessTerminalStage stage;

  @override
  State<AccessTerminalTransition> createState() =>
      _AccessTerminalTransitionState();
}

class _AccessTerminalTransitionState extends State<AccessTerminalTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool? _reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) {
      return;
    }
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 0.58;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = _reduceMotion ?? false;
    final String status = switch (widget.stage) {
      AccessTerminalStage.validating => 'VALIDANDO SECUENCIA',
      AccessTerminalStage.opening => 'ACCESO AUTORIZADO',
    };
    final String detail = switch (widget.stage) {
      AccessTerminalStage.validating => 'DERIVACIÓN SEGURA EN CURSO',
      AccessTerminalStage.opening => 'MONTANDO BÓVEDA CIFRADA',
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) => CustomPaint(
                    painter: _TerminalDataRainPainter(
                      accentColor: widget.accentColor,
                      progress: _controller.value,
                      staticFrame: reduceMotion,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(TerminalSpace.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label: '$status. $detail.',
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _TerminalTransitionHeader(
                            accentColor: widget.accentColor,
                          ),
                          const SizedBox(height: TerminalSpace.xl),
                          AnimatedBuilder(
                            animation: _controller,
                            child: Text(
                              'ENLACE DE TERMINAL',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    color: widget.accentColor,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.8,
                                  ),
                            ),
                            builder: (BuildContext context, Widget? child) =>
                                Transform.translate(
                                  offset: Offset(
                                    reduceMotion
                                        ? 0
                                        : _glitchOffset(_controller.value),
                                    0,
                                  ),
                                  child: child,
                                ),
                          ),
                          const SizedBox(height: TerminalSpace.lg),
                          Container(
                            padding: const EdgeInsets.all(TerminalSpace.lg),
                            decoration: ShapeDecoration(
                              color: Colors.black,
                              shape: TerminalCutCornerBorder(
                                cut: 14,
                                side: BorderSide(
                                  color: widget.accentColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Column(
                              children: <Widget>[
                                Icon(
                                  widget.stage == AccessTerminalStage.validating
                                      ? Icons.shield_outlined
                                      : Icons.lock_open_outlined,
                                  color: widget.accentColor,
                                  size: 42,
                                ),
                                const SizedBox(height: TerminalSpace.md),
                                Text(
                                  status,
                                  key: const Key(
                                    'access-terminal-transition-status',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: widget.accentColor,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                                const SizedBox(height: TerminalSpace.xs),
                                Text(
                                  detail,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: widget.accentColor.withValues(
                                          alpha: 0.82,
                                        ),
                                        letterSpacing: 0.9,
                                      ),
                                ),
                                const SizedBox(height: TerminalSpace.lg),
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder:
                                      (BuildContext context, Widget? child) =>
                                          _TerminalLoadingSegments(
                                            accentColor: widget.accentColor,
                                            progress: _controller.value,
                                            staticFrame: reduceMotion,
                                          ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: TerminalSpace.md),
                          Text(
                            'CANAL AISLADO · SIN RED · DATOS LOCALES',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: widget.accentColor.withValues(
                                    alpha: 0.72,
                                  ),
                                  letterSpacing: 1.1,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _glitchOffset(double progress) {
    if ((progress > 0.18 && progress < 0.22) ||
        (progress > 0.64 && progress < 0.68)) {
      return progress < 0.5 ? -2 : 2;
    }
    return 0;
  }
}

class _TerminalTransitionHeader extends StatelessWidget {
  const _TerminalTransitionHeader({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          border: Border.all(color: accentColor),
          color: accentColor.withValues(alpha: 0.12),
        ),
        child: Icon(Icons.memory_outlined, color: accentColor),
      ),
      const SizedBox(width: TerminalSpace.sm),
      Expanded(
        child: Text(
          'BITÁCORA // PROTOCOLO LOCAL',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ),
    ],
  );
}

class _TerminalLoadingSegments extends StatelessWidget {
  const _TerminalLoadingSegments({
    required this.accentColor,
    required this.progress,
    required this.staticFrame,
  });

  final Color accentColor;
  final double progress;
  final bool staticFrame;

  @override
  Widget build(BuildContext context) {
    final int activeSegment = staticFrame ? 7 : (progress * 12).floor();
    return Row(
      children: List<Widget>.generate(
        12,
        (int index) => Expanded(
          child: Container(
            height: 8,
            margin: EdgeInsets.only(right: index == 11 ? 0 : 4),
            color: index <= activeSegment
                ? accentColor
                : accentColor.withValues(alpha: 0.16),
          ),
        ),
      ),
    );
  }
}

class _TerminalDataRainPainter extends CustomPainter {
  const _TerminalDataRainPainter({
    required this.accentColor,
    required this.progress,
    required this.staticFrame,
  });

  static const List<String> _rows = <String>[
    '7A 55 E9 1C FF BD 7A 55 // LOCAL ENCRYPTED // 1C E9 7A',
    'E9 1C 55 7A BD FF 1C E9 // VERIFY BUFFER // 55 7A E9',
    '1C 7A FF 55 E9 1C BD 7A // TERMINAL LINK // FF 55 1C',
    '55 E9 7A 1C BD 55 FF E9 // OFFLINE VAULT // 7A 1C BD',
  ];

  final Color accentColor;
  final double progress;
  final bool staticFrame;

  @override
  void paint(Canvas canvas, Size size) {
    const double rowHeight = 42;
    final int rowCount = (size.height / rowHeight).ceil() + 2;
    final double shift = staticFrame ? 18 : progress * rowHeight;

    for (int index = -1; index < rowCount; index++) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: _rows[index.abs() % _rows.length],
          style: TextStyle(
            color: accentColor.withValues(alpha: index.isEven ? 0.075 : 0.045),
            fontFamily: 'monospace',
            fontSize: 12,
            letterSpacing: 1.1,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width + 80);
      painter.paint(
        canvas,
        Offset(index.isEven ? -12 : 14, index * rowHeight + shift),
      );
    }

    final double scanY = staticFrame
        ? size.height * 0.58
        : progress * size.height;
    canvas.drawRect(
      Rect.fromLTWH(0, scanY, size.width, 1),
      Paint()..color = accentColor.withValues(alpha: 0.32),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, scanY - 10, size.width, 20),
      Paint()..color = accentColor.withValues(alpha: 0.025),
    );
  }

  @override
  bool shouldRepaint(_TerminalDataRainPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.staticFrame != staticFrame;
}

class AccessCodeMatrix extends StatelessWidget {
  const AccessCodeMatrix({
    required this.controller,
    required this.accentColor,
    required this.onCompleted,
    this.enabled = true,
    super.key,
  });

  static const int codeLength = 6;
  static const List<String> _digits = <String>[
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];

  final TextEditingController controller;
  final Color accentColor;
  final ValueChanged<String> onCompleted;
  final bool enabled;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (BuildContext context, TextEditingValue value, Widget? child) {
          final int entered = value.text.length.clamp(0, codeLength);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _AccessBuffer(enteredDigits: entered, accentColor: accentColor),
              const SizedBox(height: 18),
              _AccessNumberGrid(
                accentColor: accentColor,
                enabled: enabled,
                onDigit: _appendDigit,
                onClear: _clear,
                onBackspace: _backspace,
              ),
            ],
          );
        },
      );

  void _appendDigit(String digit) {
    if (!enabled || controller.text.length >= codeLength) {
      return;
    }
    final String next = '${controller.text}$digit';
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    if (next.length == codeLength) {
      onCompleted(next);
    }
  }

  void _backspace() {
    if (!enabled || controller.text.isEmpty) {
      return;
    }
    final String next = controller.text.substring(
      0,
      controller.text.length - 1,
    );
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _clear() {
    if (enabled) {
      controller.clear();
    }
  }
}

class _AccessBuffer extends StatelessWidget {
  const _AccessBuffer({required this.enteredDigits, required this.accentColor});

  final int enteredDigits;
  final Color accentColor;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'BÚFER de acceso',
    value:
        '$enteredDigits de ${AccessCodeMatrix.codeLength} dígitos ingresados',
    child: ExcludeSemantics(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.memory_outlined, color: accentColor, size: 22),
              const SizedBox(width: 8),
              Text(
                'BÚFER',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: ShapeDecoration(
              color: accentColor.withValues(alpha: 0.05),
              shape: TerminalCutCornerBorder(
                cut: 8,
                side: BorderSide(color: accentColor, width: 1.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                AccessCodeMatrix.codeLength,
                (int index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Container(
                    key: ValueKey<String>('access-buffer-slot-$index'),
                    width: 28,
                    height: 34,
                    decoration: BoxDecoration(
                      color: index < enteredDigits
                          ? accentColor.withValues(alpha: 0.20)
                          : Colors.transparent,
                      border: Border.all(color: accentColor),
                    ),
                    alignment: Alignment.center,
                    child: index < enteredDigits
                        ? Container(width: 8, height: 8, color: accentColor)
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AccessNumberGrid extends StatelessWidget {
  const _AccessNumberGrid({
    required this.accentColor,
    required this.enabled,
    required this.onDigit,
    required this.onClear,
    required this.onBackspace,
  });

  final Color accentColor;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) => Container(
    decoration: ShapeDecoration(
      color: accentColor.withValues(alpha: 0.035),
      shape: TerminalCutCornerBorder(
        cut: 10,
        side: BorderSide(color: accentColor, width: 1.25),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          key: const Key('access-code-matrix-header'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: accentColor,
          child: Row(
            children: <Widget>[
              const Icon(Icons.grid_view_outlined, color: Colors.black),
              const SizedBox(width: 10),
              Text(
                'MATRIZ DE CÓDIGO',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: <Widget>[
                  for (final String digit in AccessCodeMatrix._digits)
                    _AccessMatrixKey(
                      key: ValueKey<String>('access-code-key-$digit'),
                      semanticsLabel: 'Dígito $digit',
                      accentColor: accentColor,
                      enabled: enabled,
                      onPressed: () => onDigit(digit),
                      child: Text(digit),
                    ),
                  _AccessMatrixKey(
                    key: const Key('access-code-clear'),
                    semanticsLabel: 'Borrar código completo',
                    accentColor: accentColor,
                    enabled: enabled,
                    onPressed: onClear,
                    child: const Text('C'),
                  ),
                  _AccessMatrixKey(
                    key: const Key('access-code-key-0'),
                    semanticsLabel: 'Dígito 0',
                    accentColor: accentColor,
                    enabled: enabled,
                    onPressed: () => onDigit('0'),
                    child: const Text('0'),
                  ),
                  _AccessMatrixKey(
                    key: const Key('access-code-backspace'),
                    semanticsLabel: 'Borrar último dígito',
                    accentColor: accentColor,
                    enabled: enabled,
                    onPressed: onBackspace,
                    child: const Icon(Icons.backspace_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AccessMatrixKey extends StatelessWidget {
  const _AccessMatrixKey({
    required this.semanticsLabel,
    required this.accentColor,
    required this.enabled,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final String semanticsLabel;
  final Color accentColor;
  final bool enabled;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    button: true,
    enabled: enabled,
    excludeSemantics: true,
    child: Material(
      color: accentColor.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(side: BorderSide(color: accentColor)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: IconTheme(
          data: IconThemeData(color: accentColor, size: 24),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: accentColor,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}

class PinTextField extends StatelessWidget {
  const PinTextField({
    required this.controller,
    required this.label,
    this.enabled = true,
    this.onSubmitted,
    this.autofocus = false,
    this.fieldKey,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    textField: true,
    child: TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: true,
      obscuringCharacter: '●',
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      maxLength: 6,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: null,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(labelText: label, counterText: ''),
      onSubmitted: onSubmitted,
    ),
  );
}

class RecoveryCodeField extends StatelessWidget {
  const RecoveryCodeField({
    required this.controller,
    required this.label,
    this.enabled = true,
    this.fieldKey,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    textField: true,
    child: TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.visiblePassword,
      textCapitalization: TextCapitalization.characters,
      enableSuggestions: false,
      autocorrect: false,
      maxLength: 39,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 -]')),
        LengthLimitingTextInputFormatter(39),
      ],
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );
}

class OneTimeRecoveryCode extends StatelessWidget {
  const OneTimeRecoveryCode({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens =
        Theme.of(context).extension<AppThemeTokens>() ??
        AppThemeTokens.terminal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.valueYellow),
      ),
      child: Text(
        code,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tokens.valueYellow,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class AccessNoticeBanner extends StatelessWidget {
  const AccessNoticeBanner({
    required this.notice,
    this.blockedUntilEpochMillis,
    super.key,
  });

  final AccessNotice? notice;
  final int? blockedUntilEpochMillis;

  @override
  Widget build(BuildContext context) {
    final AccessNotice? value = notice;
    if (value == null) {
      return const SizedBox.shrink();
    }
    final AppThemeTokens tokens =
        Theme.of(context).extension<AppThemeTokens>() ??
        AppThemeTokens.terminal;

    final bool isSuccess = switch (value) {
      AccessNotice.pinChanged ||
      AccessNotice.biometricsEnabled ||
      AccessNotice.biometricsDisabled => true,
      _ => false,
    };

    final String text = switch (value) {
      AccessNotice.pinMismatch => 'Los dos PIN no coinciden.',
      AccessNotice.pinPolicyRejected =>
        'Usa seis dígitos no repetidos y evita secuencias obvias.',
      AccessNotice.invalidCredential => 'La credencial no es válida.',
      AccessNotice.progressiveWait => _blockedMessage(),
      AccessNotice.recoveryCodeMismatch =>
        'El código escrito no coincide con el código mostrado.',
      AccessNotice.biometricUnavailable =>
        'La biometría no está disponible o no está configurada.',
      AccessNotice.biometricCancelled => 'Autenticación biométrica cancelada.',
      AccessNotice.biometricLockedOut =>
        'La biometría está bloqueada. Usa tu PIN de la app.',
      AccessNotice.biometricFailed =>
        'No se pudo confirmar la biometría. Usa tu PIN.',
      AccessNotice.credentialStateCorrupted =>
        'El estado de acceso no es legible. La aplicación permanece cerrada.',
      AccessNotice.pinChanged => 'PIN actualizado correctamente.',
      AccessNotice.biometricsEnabled => 'Biometría activada.',
      AccessNotice.biometricsDisabled => 'Biometría desactivada.',
      AccessNotice.sessionTimedOut =>
        'La sesión se bloqueó por permanecer fuera de la app.',
    };

    final Color bgColor = isSuccess
        ? tokens.progressGreen.withValues(alpha: 0.4)
        : tokens.structuralRed.withValues(alpha: 0.4);
    final Color borderColor = isSuccess
        ? tokens.progressGreen
        : tokens.attentionOrange;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text),
    );
  }

  String _blockedMessage() {
    final int? until = blockedUntilEpochMillis;
    if (until == null) {
      return 'Demasiados intentos. Espera antes de volver a probar.';
    }
    final Duration remaining = DateTime.fromMillisecondsSinceEpoch(
      until,
    ).difference(DateTime.now());
    final int seconds = remaining.inSeconds.clamp(1, 900);
    return 'Demasiados intentos. Vuelve a probar en aproximadamente '
        '$seconds segundos.';
  }
}
