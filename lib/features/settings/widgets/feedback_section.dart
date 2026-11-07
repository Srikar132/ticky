import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/widgets/form_card.dart';
import 'package:ticky/features/settings/models/feedback_prefs.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';

/// Ticky's own taps and celebration: a small buzz and the system click. The
/// reminder sound and vibration live under Notifications.
class FeedbackSection extends ConsumerWidget {
  const FeedbackSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs =
        ref.watch(feedbackPrefsProvider).value ?? const FeedbackPrefs();
    final actions = ref.read(settingsActionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Feedback'),
        FormCard(
          children: [
            SwitchRow(
              icon: Icons.touch_app_outlined,
              label: 'Haptics',
              subtitle: 'A small buzz on taps, checks and celebrations',
              value: prefs.haptics,
              onChanged: actions.setHapticsEnabled,
            ),
            const Divider(),
            SwitchRow(
              icon: Icons.graphic_eq_rounded,
              label: 'Sound effects',
              subtitle: 'A soft click, using the phone’s own sound',
              value: prefs.sounds,
              onChanged: actions.setSoundEffectsEnabled,
            ),
          ],
        ),
      ],
    );
  }
}
