import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/notifications/reminder_planner.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/core/widgets/form_card.dart';
import 'package:ticky/features/home/widgets/notification_permission_sheet.dart';
import 'package:ticky/features/settings/models/notification_prefs.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';
import 'package:ticky/features/settings/widgets/snooze_sheet.dart';

/// Reminders, sound, vibration, follow-up and default snooze.
class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs =
        ref.watch(notificationPrefsProvider).value ?? const NotificationPrefs();
    final permission = ref.watch(notificationPermissionProvider).value;
    final actions = ref.read(settingsActionsProvider);
    final on = prefs.notificationsEnabled;
    final blocked = permission != null && !permission.notificationsAllowed;

    Future<void> offerPermission() async {
      await showNotificationPermissionSheet(context, ref);
      ref.invalidate(notificationPermissionProvider);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Notifications'),
        FormCard(
          children: [
            if (blocked) ...[
              FormRow(
                icon: Icons.notifications_off_outlined,
                label: 'Notifications are blocked',
                subtitle: 'Allow them so reminders can reach you',
                onTap: offerPermission,
              ),
              const Divider(),
            ],
            SwitchRow(
              icon: Icons.notifications_none_rounded,
              label: 'Reminders',
              value: on,
              onChanged: (value) async {
                final needsPermission = await actions.setRemindersEnabled(
                  value,
                );
                if (needsPermission && context.mounted) await offerPermission();
              },
            ),
            const Divider(),
            SwitchRow(
              icon: Icons.volume_up_outlined,
              label: 'Sound',
              value: prefs.soundEnabled,
              onChanged: on ? actions.setSoundEnabled : null,
            ),
            const Divider(),
            SwitchRow(
              icon: Icons.vibration_rounded,
              label: 'Vibration',
              value: prefs.vibrationEnabled,
              onChanged: on ? actions.setVibrationEnabled : null,
            ),
            const Divider(),
            SwitchRow(
              icon: Icons.replay_rounded,
              label: 'Follow-up',
              subtitle:
                  'One nudge ${const ReminderPlanner().followUpDelayMinutes} minutes later if a task is still open',
              value: prefs.followUpEnabled,
              onChanged: on ? actions.setFollowUpEnabled : null,
            ),
            const Divider(),
            FormRow(
              icon: Icons.snooze_rounded,
              label: 'Default snooze',
              value: formatDuration(prefs.defaultSnoozeMinutes),
              dimmed: !on,
              onTap: on
                  ? () async {
                      final minutes = await showSnoozeSheet(
                        context,
                        current: prefs.defaultSnoozeMinutes,
                      );
                      if (minutes != null) {
                        await actions.setDefaultSnoozeMinutes(minutes);
                      }
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
