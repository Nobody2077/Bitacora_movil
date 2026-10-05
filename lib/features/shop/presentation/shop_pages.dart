import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/app_ui_preferences.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../economy/application/economy_providers.dart';
import '../../economy/domain/models/economy_models.dart';
import '../../economy/presentation/economy_presentation_support.dart';
import '../../journal/presentation/journal_presentation_support.dart';
import '../../missions/application/mission_providers.dart';
import '../../missions/domain/models/mission.dart';
import '../../missions/presentation/mission_presentation_support.dart';
import '../application/shop_application_service.dart';
import '../application/shop_providers.dart';
import '../domain/models/wish.dart';
import '../domain/models/wish_affordability.dart';
import 'shop_presentation_support.dart';

enum _ShopMode { wishes, purchased, archived }

/// TIENDA (ADR-006 D17): la lista de deseos, lo comprado y lo archivado.
class ShopSection extends ConsumerStatefulWidget {
  const ShopSection({super.key});

  @override
  ConsumerState<ShopSection> createState() => _ShopSectionState();
}

class _ShopSectionState extends ConsumerState<ShopSection> {
  _ShopMode _mode = _ShopMode.wishes;

  StreamProvider<List<Wish>> get _provider => switch (_mode) {
    _ShopMode.wishes => activeWishesProvider,
    _ShopMode.purchased => purchasedWishesProvider,
    _ShopMode.archived => archivedWishesProvider,
  };

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final AsyncValue<List<Wish>> wishes = ref.watch(_provider);
    final List<MissionArea>? areas = ref.watch(missionAreasProvider).value;
    final int? available = ref
        .watch(economySnapshotProvider)
        .value
        ?.availableMinor;
    final int? wishCount = ref.watch(activeWishesProvider).value?.length;

    return ListView(
      padding: TerminalSpace.pageTablet,
      children: <Widget>[
        Wrap(
          spacing: TerminalSpace.xs,
          runSpacing: TerminalSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _ModeChip(
              key: const Key('shop-mode-wishes'),
              label: wishCount == null ? 'DESEOS' : 'DESEOS · $wishCount',
              selected: _mode == _ShopMode.wishes,
              onPressed: () => setState(() => _mode = _ShopMode.wishes),
            ),
            _ModeChip(
              key: const Key('shop-mode-purchased'),
              label: 'COMPRADOS',
              selected: _mode == _ShopMode.purchased,
              onPressed: () => setState(() => _mode = _ShopMode.purchased),
            ),
            _ModeChip(
              key: const Key('shop-mode-archived'),
              label: 'ARCHIVADOS',
              selected: _mode == _ShopMode.archived,
              onPressed: () => setState(() => _mode = _ShopMode.archived),
            ),
            const SizedBox(width: TerminalSpace.sm),
            TerminalPrimaryButton(
              key: const Key('wish-create'),
              label: 'Añadir deseo',
              icon: Icons.add,
              onPressed: () => context.pushNamed('wishNew'),
            ),
          ],
        ),
        const SizedBox(height: TerminalSpace.md),
        wishes.when(
          data: (List<Wish> items) => items.isEmpty
              ? TerminalEmptyState(
                  title: switch (_mode) {
                    _ShopMode.wishes => 'Tu lista de deseos está vacía',
                    _ShopMode.purchased => 'Aún no compraste nada',
                    _ShopMode.archived => 'No hay deseos archivados',
                  },
                  description: switch (_mode) {
                    _ShopMode.wishes =>
                      'Apunta lo que quieres comprar con su precio y te dirá '
                          'si tu saldo ya alcanza.',
                    _ShopMode.purchased =>
                      'Lo que compres desde un deseo aparecerá aquí.',
                    _ShopMode.archived =>
                      'Los deseos que elimines aparecerán aquí.',
                  },
                  icon: Icons.storefront_outlined,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final Wish wish in items) ...<Widget>[
                      WishCard(
                        wish: wish,
                        areas: areas,
                        availableMinor: _mode == _ShopMode.wishes
                            ? available
                            : null,
                        trailing: _mode == _ShopMode.purchased
                            ? _PurchasedTrailing(wish: wish)
                            : null,
                        onTap: () => context.pushNamed(
                          'wishDetail',
                          pathParameters: <String, String>{'wishId': wish.id},
                        ),
                      ),
                      const SizedBox(height: TerminalSpace.sm),
                    ],
                  ],
                ),
          loading: () => const TerminalLoadingState(message: 'Cargando…'),
          error: (_, _) => TerminalErrorState(
            title: 'No se pudo leer la Tienda',
            description: 'Reintenta la lectura desde la base local cifrada.',
            onRetry: () => ref.invalidate(_provider),
          ),
        ),
        if (_mode == _ShopMode.wishes && available == null)
          Text(
            'Calculando tu saldo disponible…',
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? tokens.infoCyan : tokens.textSecondary,
          side: BorderSide(color: selected ? tokens.infoCyan : tokens.border),
          minimumSize: const Size(48, 44),
          textStyle: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Fecha y precio pagado de un deseo comprado.
class _PurchasedTrailing extends ConsumerWidget {
  const _PurchasedTrailing({required this.wish});

  final Wish wish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final EconomyTransaction? expense = wish.purchaseTransactionId == null
        ? null
        : ref
              .watch(
                economyTransactionDetailProvider(wish.purchaseTransactionId!),
              )
              .value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (expense != null)
          Text(
            economyMoney(context, expense.amountMinor).trim(),
            style: TextStyle(
              color: tokens.valueYellow,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w700,
            ),
          ),
        if (wish.purchasedAtUtc != null)
          Text(
            economyDateTimeLabel(wish.purchasedAtUtc!).split(' · ').first,
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
          ),
      ],
    );
  }
}

/// Ficha de un deseo: datos, si te alcanza y las acciones.
class WishDetailPage extends ConsumerStatefulWidget {
  const WishDetailPage({required this.wishId, super.key});

  final String wishId;

  @override
  ConsumerState<WishDetailPage> createState() => _WishDetailPageState();
}

class _WishDetailPageState extends ConsumerState<WishDetailPage> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Wish?> wishAsync = ref.watch(wishProvider(widget.wishId));
    return wishAsync.when(
      loading: () => const TerminalAsyncStatePage(
        child: TerminalLoadingState(message: 'Abriendo deseo…'),
      ),
      error: (_, _) => TerminalAsyncStatePage(
        child: TerminalErrorState(
          title: 'Deseo no disponible',
          description: 'No se pudo leer el deseo.',
          onRetry: () => ref.invalidate(wishProvider(widget.wishId)),
        ),
      ),
      data: (Wish? wish) => wish == null
          ? const TerminalAsyncStatePage(
              child: TerminalEmptyState(
                title: 'Deseo no encontrado',
                description: 'Puede que el enlace ya no sea válido.',
                icon: Icons.storefront_outlined,
              ),
            )
          : _buildDetail(context, wish),
    );
  }

  Widget _buildDetail(BuildContext context, Wish wish) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final MissionArea? area = wishAreaOf(
      wish,
      ref.watch(missionAreasProvider).value,
    );
    final int? available = ref
        .watch(economySnapshotProvider)
        .value
        ?.availableMinor;
    final WishAffordability? affordability =
        wish.isPurchased || available == null
        ? null
        : WishAffordability.evaluate(
            priceMinor: wish.priceMinor,
            availableMinor: available,
          );
    final EconomyTransaction? expense = wish.purchaseTransactionId == null
        ? null
        : ref
              .watch(
                economyTransactionDetailProvider(wish.purchaseTransactionId!),
              )
              .value;

    return JournalPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TerminalPageHeader(
            title: wish.name,
            subtitle: wishKindLabel(wish.kind),
          ),
          const SizedBox(height: TerminalSpace.sm),
          Wrap(
            spacing: TerminalSpace.xs,
            runSpacing: TerminalSpace.xs,
            children: <Widget>[
              TerminalBadge(
                label: wishKindLabel(wish.kind),
                color: tokens.infoCyan,
                icon: wishKindIcon(wish.kind),
              ),
              if (area != null)
                TerminalBadge(
                  label: area.name,
                  color: missionAreaColor(area.colorHex, tokens.infoCyan),
                  icon: missionAreaIcon(area.iconKey),
                ),
              if (wish.priority != null)
                TerminalBadge(
                  label: wishPriorityLabel(wish.priority!),
                  color: wishPriorityColor(tokens, wish.priority!),
                ),
              if (wish.isArchived)
                TerminalBadge(
                  label: 'Archivado',
                  color: tokens.attentionOrange,
                  icon: Icons.inventory_2_outlined,
                ),
              if (wish.isPurchased)
                TerminalBadge(
                  label: 'Comprado',
                  color: tokens.progressGreen,
                  icon: Icons.check_circle_outline,
                ),
            ],
          ),
          const SizedBox(height: TerminalSpace.md),
          TerminalPanel(
            borderColor: affordability == null
                ? null
                : wishAffordabilityColor(tokens, affordability.level),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (wish.isPurchased) ...<Widget>[
                  Text(
                    expense == null
                        ? 'Comprado'
                        : 'Pagaste ${economyMoney(context, expense.amountMinor).trim()}',
                    key: const Key('wish-paid'),
                    style: TextStyle(
                      color: tokens.valueYellow,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (wish.purchasedAtUtc != null)
                    Text(
                      economyDateTimeLabel(wish.purchasedAtUtc!),
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                ] else ...<Widget>[
                  Text(
                    wish.priceMinor == null
                        ? 'Sin precio orientativo'
                        : 'Precio orientativo: '
                              '${economyMoney(context, wish.priceMinor!).trim()}',
                    style: TextStyle(
                      color: tokens.valueYellow,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (affordability != null) ...<Widget>[
                    const SizedBox(height: TerminalSpace.xxs),
                    Text(
                      wishAffordabilityLabel(context, affordability),
                      key: const Key('wish-detail-affordability'),
                      style: TextStyle(
                        color: wishAffordabilityColor(
                          tokens,
                          affordability.level,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: TerminalSpace.md),
          if (wish.description != null)
            Text(
              wish.description!,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5),
            )
          else
            Text(
              'Sin información.',
              style: TextStyle(color: tokens.textSecondary),
            ),
          const SizedBox(height: TerminalSpace.lg),
          if (!wish.isPurchased)
            Wrap(
              spacing: TerminalSpace.sm,
              runSpacing: TerminalSpace.sm,
              children: <Widget>[
                if (!wish.isArchived) ...<Widget>[
                  TerminalPrimaryButton(
                    key: const Key('wish-purchase'),
                    label: 'Comprar',
                    icon: Icons.shopping_cart_checkout,
                    onPressed: _working ? null : () => _purchase(wish),
                  ),
                  TerminalOutlineButton(
                    key: const Key('wish-edit'),
                    label: 'Editar',
                    icon: Icons.edit_outlined,
                    onPressed: _working
                        ? null
                        : () => context.pushNamed(
                            'wishEdit',
                            pathParameters: <String, String>{'wishId': wish.id},
                          ),
                  ),
                  TerminalOutlineButton(
                    key: const Key('wish-archive'),
                    label: 'Eliminar',
                    icon: Icons.inventory_2_outlined,
                    color: tokens.attentionOrange,
                    onPressed: _working ? null : () => _archive(wish),
                  ),
                ] else
                  TerminalPrimaryButton(
                    key: const Key('wish-restore'),
                    label: 'Restaurar',
                    icon: Icons.unarchive_outlined,
                    onPressed: _working ? null : () => _restore(wish),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _archive(Wish wish) async {
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Eliminar deseo'),
        content: const Text(
          'Se archiva: deja de salir en tu lista. Puedes restaurarlo desde '
          'Archivados.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('wish-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await _run(
      () => ref.read(shopApplicationServiceProvider).archive(wish),
      success: 'Deseo archivado.',
    );
  }

  Future<void> _restore(Wish wish) => _run(
    () => ref.read(shopApplicationServiceProvider).restore(wish),
    success: 'Deseo restaurado.',
  );

  Future<void> _purchase(Wish wish) async {
    final _PurchaseInput? input = await showDialog<_PurchaseInput>(
      context: context,
      builder: (BuildContext dialogContext) => _PurchaseDialog(wish: wish),
    );
    if (input == null || !mounted) return;
    final int? balanceBefore = ref
        .read(economySnapshotProvider)
        .value
        ?.availableMinor;
    setState(() => _working = true);
    final Result<Wish> result = await ref
        .read(shopApplicationServiceProvider)
        .purchase(
          PurchaseWishRequest(
            wish: wish,
            amountMinor: input.amountMinor,
            paymentMethod: input.paymentMethod,
          ),
        );
    if (!mounted) return;
    setState(() => _working = false);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    result.fold<void>(
      onSuccess: (_) {
        if (balanceBefore != null) {
          ref
              .read(purchaseFeedbackProvider.notifier)
              .announce(
                PurchaseFeedback(
                  amountMinor: input.amountMinor,
                  balanceBeforeMinor: balanceBefore,
                ),
              );
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Comprado · − ${economyMoney(context, input.amountMinor).trim()}',
            ),
          ),
        );
        _backToShop();
      },
      onFailure: (AppFailure failure) =>
          messenger.showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  /// Vuelve a la Tienda, donde la cabecera anima el saldo.
  void _backToShop() => context.canPop()
      ? context.pop()
      : context.goNamed(
          'character',
          queryParameters: const <String, String>{'tab': 'tienda'},
        );

  Future<void> _run<T>(
    Future<Result<T>> Function() action, {
    required String success,
  }) async {
    setState(() => _working = true);
    final Result<T> result = await action();
    if (!mounted) return;
    setState(() => _working = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.fold(
            onSuccess: (_) => success,
            onFailure: (AppFailure failure) => failure.message,
          ),
        ),
      ),
    );
  }
}

final class _PurchaseInput {
  const _PurchaseInput({
    required this.amountMinor,
    required this.paymentMethod,
  });

  final int amountMinor;
  final EconomyPaymentMethod paymentMethod;
}

/// Precio pagado (propone el orientativo) y medio de pago.
class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog({required this.wish});

  final Wish wish;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.wish.priceMinor == null
        ? ''
        : moneyFieldText(widget.wish.priceMinor!),
  );
  EconomyPaymentMethod _payment = EconomyPaymentMethod.cash;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Comprar «${widget.wish.name}»'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Se registra como gasto en Economía, en la categoría «Tienda».',
          ),
          const SizedBox(height: TerminalSpace.sm),
          TextFormField(
            key: const Key('wish-purchase-amount'),
            controller: _amount,
            autofocus: widget.wish.priceMinor == null,
            obscureText: context.uiPreferences.hideAmounts,
            obscuringCharacter: '•',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio pagado (Bs)',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            validator: economyPositiveMoneyValidator,
          ),
          const SizedBox(height: TerminalSpace.sm),
          DropdownButtonFormField<EconomyPaymentMethod>(
            key: const Key('wish-purchase-method'),
            initialValue: _payment,
            decoration: const InputDecoration(labelText: 'Medio de pago'),
            items: <DropdownMenuItem<EconomyPaymentMethod>>[
              for (final EconomyPaymentMethod value
                  in EconomyPaymentMethod.values)
                DropdownMenuItem<EconomyPaymentMethod>(
                  value: value,
                  child: Text(economyPaymentLabel(value)),
                ),
            ],
            onChanged: (EconomyPaymentMethod? value) =>
                setState(() => _payment = value ?? _payment),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('wish-purchase-confirm'),
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.of(context).pop(
            _PurchaseInput(
              amountMinor: parseEconomyMoney(_amount.text)!,
              paymentMethod: _payment,
            ),
          );
        },
        child: const Text('Comprar'),
      ),
    ],
  );
}

/// «400,00» para precargar un campo de dinero sin el prefijo «Bs».
String moneyFieldText(int minor) =>
    '${minor ~/ 100},${(minor % 100).toString().padLeft(2, '0')}';

/// Crear o editar un deseo.
class WishFormPage extends ConsumerStatefulWidget {
  const WishFormPage({super.key, this.wishId});

  final String? wishId;

  @override
  ConsumerState<WishFormPage> createState() => _WishFormPageState();
}

class _WishFormPageState extends ConsumerState<WishFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _price = TextEditingController();
  WishKind _kind = WishKind.other;
  WishPriority _priority = WishPriority.medium;
  String? _areaId;
  Wish? _existing;
  bool _initialized = false;
  bool _saving = false;

  bool get _isEditing => widget.wishId != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final AsyncValue<Wish?> existing = ref.watch(
        wishProvider(widget.wishId!),
      );
      if (existing.isLoading && !_initialized) {
        return const TerminalAsyncStatePage(
          child: TerminalLoadingState(message: 'Preparando deseo…'),
        );
      }
      final Wish? wish = existing.value;
      if (wish == null || wish.isArchived || wish.isPurchased) {
        return const TerminalAsyncStatePage(
          child: TerminalEmptyState(
            title: 'Deseo no disponible',
            description: 'No existe, está archivado o ya se compró.',
            icon: Icons.storefront_outlined,
          ),
        );
      }
      if (!_initialized) {
        _existing = wish;
        _name.text = wish.name;
        _description.text = wish.description ?? '';
        _price.text = wish.priceMinor == null
            ? ''
            : moneyFieldText(wish.priceMinor!);
        _kind = wish.kind;
        _priority = wish.priority ?? WishPriority.medium;
        _areaId = wish.areaId;
        _initialized = true;
      }
    }
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final List<MissionArea> areas =
        ref.watch(missionAreasProvider).value ?? const <MissionArea>[];
    final bool areaKnown =
        _areaId == null || areas.any((MissionArea a) => a.id == _areaId);

    return JournalPageFrame(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TerminalPageHeader(
              title: _isEditing ? 'Editar deseo' : 'Añadir deseo',
              subtitle: 'Lo que quieres comprar, con su precio orientativo',
            ),
            const SizedBox(height: TerminalSpace.md),
            TerminalPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    key: const Key('wish-name'),
                    controller: _name,
                    autofocus: !_isEditing,
                    maxLength: Wish.maxNameLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    validator: (String? value) => (value ?? '').trim().isEmpty
                        ? 'El deseo necesita un nombre.'
                        : null,
                  ),
                  const SizedBox(height: TerminalSpace.sm),
                  TextFormField(
                    key: const Key('wish-price'),
                    controller: _price,
                    obscureText: context.uiPreferences.hideAmounts,
                    obscuringCharacter: '•',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Precio orientativo en Bs (opcional)',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                    validator: (String? value) => (value ?? '').trim().isEmpty
                        ? null
                        : economyPositiveMoneyValidator(value),
                  ),
                  const SizedBox(height: TerminalSpace.sm),
                  DropdownButtonFormField<String?>(
                    key: const Key('wish-area'),
                    initialValue: areaKnown ? _areaId : null,
                    decoration: const InputDecoration(
                      labelText: 'Área de vida',
                      prefixIcon: Icon(Icons.track_changes_outlined),
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(child: Text('Sin área')),
                      for (final MissionArea area in areas)
                        DropdownMenuItem<String?>(
                          value: area.id,
                          child: Text(area.name),
                        ),
                    ],
                    onChanged: (String? value) =>
                        setState(() => _areaId = value),
                  ),
                  const SizedBox(height: TerminalSpace.sm),
                  DropdownButtonFormField<WishKind>(
                    key: const Key('wish-kind'),
                    initialValue: _kind,
                    decoration: const InputDecoration(
                      labelText: 'Tipo (decide el icono)',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: <DropdownMenuItem<WishKind>>[
                      for (final WishKind kind in WishKind.values)
                        DropdownMenuItem<WishKind>(
                          value: kind,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(wishKindIcon(kind), size: 20),
                              const SizedBox(width: TerminalSpace.xs),
                              Text(wishKindLabel(kind)),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (WishKind? value) =>
                        setState(() => _kind = value ?? _kind),
                  ),
                  const SizedBox(height: TerminalSpace.sm),
                  DropdownButtonFormField<WishPriority>(
                    key: const Key('wish-priority'),
                    initialValue: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Prioridad',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: <DropdownMenuItem<WishPriority>>[
                      for (final WishPriority priority in <WishPriority>[
                        WishPriority.high,
                        WishPriority.medium,
                        WishPriority.low,
                      ])
                        DropdownMenuItem<WishPriority>(
                          value: priority,
                          child: Text(wishPriorityLabel(priority)),
                        ),
                    ],
                    onChanged: (WishPriority? value) =>
                        setState(() => _priority = value ?? _priority),
                  ),
                  const SizedBox(height: TerminalSpace.sm),
                  TextFormField(
                    key: const Key('wish-description'),
                    controller: _description,
                    minLines: 4,
                    maxLines: 10,
                    maxLength: Wish.maxDescriptionLength,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Información (modelo, tienda, notas…)',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TerminalSpace.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: TerminalSpace.sm,
              runSpacing: TerminalSpace.sm,
              children: <Widget>[
                TerminalOutlineButton(
                  label: 'Cancelar',
                  icon: Icons.close,
                  color: tokens.textSecondary,
                  onPressed: _saving ? null : _close,
                ),
                TerminalPrimaryButton(
                  key: const Key('wish-save'),
                  label: _saving ? 'Guardando' : 'Guardar deseo',
                  icon: _saving ? Icons.hourglass_top : Icons.save_outlined,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final String priceText = _price.text.trim();
    final Result<Wish> result = await ref
        .read(shopApplicationServiceProvider)
        .save(
          SaveWishRequest(
            existing: _existing,
            name: _name.text,
            description: _description.text,
            areaId: _areaId,
            kind: _kind,
            priority: _priority,
            priceMinor: priceText.isEmpty ? null : parseEconomyMoney(priceText),
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold<void>(
      onSuccess: (Wish wish) {
        if (_isEditing) {
          _close();
        } else {
          context.pushReplacementNamed(
            'wishDetail',
            pathParameters: <String, String>{'wishId': wish.id},
          );
        }
      },
      onFailure: (AppFailure failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  void _close() => context.canPop()
      ? context.pop()
      : context.goNamed(
          'character',
          queryParameters: const <String, String>{'tab': 'tienda'},
        );
}
