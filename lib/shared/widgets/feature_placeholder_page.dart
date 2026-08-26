import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_route_contract.dart';
import '../../app/router/app_routes.dart';
import '../../app/theme/app_theme_tokens.dart';
import 'terminal/terminal_widgets.dart';

class FeaturePlaceholderPage extends StatelessWidget {
  const FeaturePlaceholderPage({
    required this.contract,
    required this.location,
    super.key,
  }) : error = null;

  const FeaturePlaceholderPage.error({
    required this.location,
    required this.error,
    super.key,
  }) : contract = null;

  final AppRouteContract? contract;
  final String location;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final AppRouteContract? current = contract;
    final bool hasError = current == null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: TerminalPanel(
                borderColor: hasError
                    ? tokens.attentionOrange
                    : tokens.structuralRed,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TerminalLabel(
                      hasError ? 'Ruta no disponible' : 'A0 · Contrato activo',
                      color: hasError
                          ? tokens.attentionOrange
                          : tokens.infoCyan,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      current?.title ?? 'No se pudo abrir esta superficie',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasError
                          ? 'La navegación rechazó la dirección solicitada de forma segura.'
                          : 'La ruta ya forma parte del contrato canónico. Su comportamiento se implementará en la fase asignada.',
                    ),
                    const SizedBox(height: 20),
                    _TechnicalValue(label: 'URI', value: location),
                    if (current != null) ...<Widget>[
                      const SizedBox(height: 8),
                      _TechnicalValue(
                        label: 'ÁREA',
                        value: current.area.name.toUpperCase(),
                      ),
                    ],
                    if (error != null) ...<Widget>[
                      const SizedBox(height: 8),
                      _TechnicalValue(
                        label: 'DIAGNÓSTICO',
                        value: error.runtimeType.toString(),
                      ),
                    ],
                    if (hasError) ...<Widget>[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => context.go(AppRoutes.home),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Volver a Inicio'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TechnicalValue extends StatelessWidget {
  const _TechnicalValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 104,
          child: TerminalLabel(label, color: tokens.valueYellow),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontFamily: 'JetBrains Mono'),
          ),
        ),
      ],
    );
  }
}
