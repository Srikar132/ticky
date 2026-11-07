import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/widgets/form_card.dart';
import 'package:ticky/core/widgets/pill_segments.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';

/// Theme: follow the system, or force light or dark.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Appearance'),
        FormCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: PillSegments<ThemeMode>(
                selected: mode,
                onChanged: ref.read(themeModeProvider.notifier).select,
                options: const [
                  PillOption(
                    value: ThemeMode.system,
                    label: 'System',
                    icon: Icons.brightness_auto_rounded,
                  ),
                  PillOption(
                    value: ThemeMode.light,
                    label: 'Light',
                    icon: Icons.light_mode_rounded,
                  ),
                  PillOption(
                    value: ThemeMode.dark,
                    label: 'Dark',
                    icon: Icons.dark_mode_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
