import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../economy/application/economy_providers.dart';
import '../../economy/presentation/economy_presentation_support.dart';
import '../application/shop_providers.dart';

/// Saldo disponible de las cabeceras (Personaje y la barra de la app). Tras una compra de la Tienda baja cifra a cifra en
/// naranja y sale «− Bs X» flotando (ADR-006 D12); con movimiento reducido
/// cambia sin animar y con importes ocultos sigue tapado.
class AnimatedBalance extends ConsumerStatefulWidget {
  const AnimatedBalance({super.key});

  @override
  ConsumerState<AnimatedBalance> createState() => _AnimatedBalanceState();
}

class _AnimatedBalanceState extends ConsumerState<AnimatedBalance>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 1400);

  late final AnimationController _controller;
  PurchaseFeedback? _playing;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    // Si la compra se hizo con el menú fuera de pantalla, se anima al volver.
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    if (!mounted) return;
    final PurchaseFeedback? feedback = ref
        .read(purchaseFeedbackProvider.notifier)
        .take();
    if (feedback == null || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    setState(() => _playing = feedback);
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _playing = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PurchaseFeedback?>(purchaseFeedbackProvider, (
      PurchaseFeedback? previous,
      PurchaseFeedback? next,
    ) {
      if (next != null) _play();
    });
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final int? available = ref
        .watch(economySnapshotProvider)
        .value
        ?.availableMinor;
    final PurchaseFeedback? playing = _playing;
    if (available == null) {
      return _text('Bs --', tokens.valueYellow);
    }
    if (playing == null) {
      return _text(economyMoney(context, available).trim(), tokens.valueYellow);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeOutCubic.transform(_controller.value);
        final int shown =
            playing.balanceBeforeMinor +
            ((available - playing.balanceBeforeMinor) * t).round();
        final double fade = 1 - Curves.easeIn.transform(_controller.value);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerRight,
          children: <Widget>[
            _text(economyMoney(context, shown).trim(), tokens.attentionOrange),
            Positioned(
              right: 0,
              top: -6 - 26 * _controller.value,
              child: Opacity(
                opacity: fade.clamp(0, 1),
                child: Text(
                  '− ${economyMoney(context, playing.amountMinor).trim()}',
                  key: const Key('character-balance-spent'),
                  style: TextStyle(
                    color: tokens.attentionOrange,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _text(String value, Color color) => Text(
    value,
    key: const Key('character-balance'),
    style: TextStyle(
      color: color,
      fontFamily: 'JetBrains Mono',
      fontSize: 22,
      fontWeight: FontWeight.w700,
    ),
  );
}
