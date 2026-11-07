import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/feedback/app_feedback.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/core/widgets/form_card.dart';
import 'package:ticky/features/character/models/mascot_mood.dart';
import 'package:ticky/features/character/widgets/ticky_mascot.dart';
import 'package:ticky/features/rewards/models/shop_item.dart';
import 'package:ticky/features/rewards/providers/reward_providers.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';

/// Spend coins on poses for Ticky. One Ticky is shown, trying on whatever row
/// is tapped; the rows themselves are plain text.
class TickyShopSection extends ConsumerStatefulWidget {
  const TickyShopSection({super.key});

  @override
  ConsumerState<TickyShopSection> createState() => _TickyShopSectionState();
}

class _TickyShopSectionState extends ConsumerState<TickyShopSection> {
  /// The row being tried on. Follows what Ticky wears until the user taps one.
  bool _picked = false;
  String? _pickedKey;

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _tryOn(String? key) => setState(() {
    _picked = true;
    _pickedKey = key;
  });

  Future<void> _buy(ShopItem item, int balance) async {
    if (balance < item.price) {
      _say('Not enough coins yet. You need ${item.price - balance} more.');
      return;
    }
    try {
      await ref.read(shopActionsProvider).buy(item);
      AppFeedback.success();
      if (!mounted) return;
      setState(() => _picked = false);
      _say('Ticky is now ${item.name}');
    } on DataException catch (error) {
      if (mounted) _say(error.message);
    }
  }

  Future<void> _wear(String? key) async {
    try {
      await ref.read(shopActionsProvider).equip(key);
      AppFeedback.tap();
      if (mounted) setState(() => _picked = false);
    } on DataException catch (error) {
      if (mounted) _say(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(coinBalanceProvider).value ?? 0;
    final owned = ref.watch(unlockedItemKeysProvider).value ?? const {};
    final equipped = ref.watch(equippedItemKeyProvider).value;
    final wornKey = (equipped != null && owned.contains(equipped))
        ? equipped
        : null;
    final previewKey = _picked ? _pickedKey : wornKey;
    final colors = context.tickyColors;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Ticky'),
        Center(
          child: TickyMascot(
            mood: MascotMood.idle,
            idlePose: shopItemFor(previewKey)?.pose,
            height: 120,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.monetization_on_rounded, size: 18, color: colors.coin),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                '$balance ${balance == 1 ? 'coin' : 'coins'}',
                style: text.labelLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FormCard(
          children: [
            _ShopRow(
              name: 'Classic',
              note: 'Ticky as he comes',
              previewed: previewKey == null,
              action: wornKey == null
                  ? const _Wearing()
                  : TextButton(
                      onPressed: () => _wear(null),
                      child: const Text('Wear'),
                    ),
              onTap: () => _tryOn(null),
            ),
            for (final item in shopItems) ...[
              const Divider(),
              _ShopRow(
                key: ValueKey('shop-${item.key}'),
                name: item.name,
                note: owned.contains(item.key) ? 'Yours' : null,
                previewed: previewKey == item.key,
                action: !owned.contains(item.key)
                    ? OutlinedButton.icon(
                        onPressed: () => _buy(item, balance),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          foregroundColor: balance >= item.price
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                        icon: Icon(
                          Icons.monetization_on_rounded,
                          size: 16,
                          color: colors.coin,
                        ),
                        label: Text('${item.price}'),
                      )
                    : wornKey == item.key
                    ? const _Wearing()
                    : TextButton(
                        onPressed: () => _wear(item.key),
                        child: const Text('Wear'),
                      ),
                onTap: () => _tryOn(item.key),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    super.key,
    required this.name,
    required this.previewed,
    required this.action,
    required this.onTap,
    this.note,
  });

  final String name;
  final String? note;
  final bool previewed;
  final Widget action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Icon(
              previewed
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: previewed ? scheme.secondary : scheme.outline,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: text.bodyLarge),
                  if (note != null) Text(note!, style: text.bodySmall),
                ],
              ),
            ),
            action,
          ],
        ),
      ),
    );
  }
}

class _Wearing extends StatelessWidget {
  const _Wearing();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 16, color: scheme.secondary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Wearing',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: scheme.secondary),
          ),
        ],
      ),
    );
  }
}
