import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/character/models/mascot_mood.dart';
import 'package:ticky/features/character/widgets/ticky_mascot.dart';
import 'package:ticky/features/home/providers/notification_prompt_controller.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';

/// Opens the "turn on reminders" sheet. Nothing is requested from the system
/// until the user taps the button inside it.
///
/// If the sheet closes without reminders being turned on, the time is
/// remembered so the user is not asked again right away.
Future<void> showNotificationPermissionSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final enabled = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const NotificationPermissionSheet(),
  );
  if (enabled == true || !context.mounted) return;
  await ref
      .read(settingsRepositoryProvider)
      .setNotificationPromptDismissedAt(ref.read(clockProvider)());
}

class NotificationPermissionSheet extends ConsumerStatefulWidget {
  const NotificationPermissionSheet({super.key});

  @override
  ConsumerState<NotificationPermissionSheet> createState() =>
      _NotificationPermissionSheetState();
}

class _NotificationPermissionSheetState
    extends ConsumerState<NotificationPermissionSheet>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The user may have flipped a switch in system settings and come back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationPromptControllerProvider.notifier).recheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(notificationPromptControllerProvider);
    final controller = ref.read(notificationPromptControllerProvider.notifier);

    ref.listen(notificationPromptControllerProvider, (previous, next) {
      if (next == PromptStep.done) {
        final navigator = Navigator.of(context);
        Future<void>.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) navigator.pop(true);
        });
      }
    });

    final content = switch (step) {
      PromptStep.ask || PromptStep.working => _Page(
        key: const ValueKey('ask'),
        mood: MascotMood.excited,
        title: 'Let Ticky remind you',
        body:
            'Turn on notifications so your reminders reach you on time, even when the app is closed.',
        extra: const _Benefits(),
        primaryLabel: 'Turn on reminders',
        loading: step == PromptStep.working,
        onPrimary: controller.enable,
        secondaryLabel: 'Maybe later',
        onSecondary: () => Navigator.of(context).pop(false),
      ),
      PromptStep.needsExact => _Page(
        key: const ValueKey('exact'),
        mood: MascotMood.happy,
        title: 'Almost there!',
        body:
            'Allow exact timing so reminders ring right on the minute. Without it they can arrive a few minutes late.',
        primaryLabel: 'Allow exact timing',
        onPrimary: controller.allowExactTiming,
        secondaryLabel: 'Skip, a little late is fine',
        onSecondary: () => Navigator.of(context).pop(true),
      ),
      PromptStep.denied => _Page(
        key: const ValueKey('denied'),
        mood: MascotMood.overdue,
        title: 'Notifications are off',
        body:
            'Ticky cannot remind you while they are blocked. You can turn them on in your phone settings.',
        primaryLabel: 'Open settings',
        onPrimary: controller.openSystemSettings,
        secondaryLabel: 'Not now',
        onSecondary: () => Navigator.of(context).pop(false),
      ),
      PromptStep.done => const _Page(
        key: ValueKey('done'),
        mood: MascotMood.celebrating,
        title: "You're all set!",
        body: 'Ticky will remind you right on time.',
      ),
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: AnimatedSize(
          duration: AppMotion.medium,
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(duration: AppMotion.medium, child: content),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    super.key,
    required this.mood,
    required this.title,
    required this.body,
    this.extra,
    this.primaryLabel,
    this.onPrimary,
    this.loading = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  final MascotMood mood;
  final String title;
  final String body;
  final Widget? extra;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool loading;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: TickyMascot(mood: mood, height: 120)),
        const SizedBox(height: AppSpacing.lg),
        Text(title, style: text.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          body,
          style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        if (extra != null) ...[const SizedBox(height: AppSpacing.lg), extra!],
        if (primaryLabel != null) ...[
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: loading ? null : onPrimary,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              child: loading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Text(primaryLabel!, key: const ValueKey('label')),
            ),
          ),
        ],
        if (secondaryLabel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: loading ? null : onSecondary,
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(secondaryLabel!),
          ),
        ],
      ],
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _Benefit(icon: Icons.alarm_rounded, text: 'Reminders right on time'),
        _Benefit(
          icon: Icons.notifications_active_outlined,
          text: 'Alarm-style alerts for what matters',
        ),
        _Benefit(
          icon: Icons.favorite_border_rounded,
          text: 'One gentle nudge if you forget',
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: AppRadius.smAll,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(icon, size: 18, color: scheme.tertiary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
