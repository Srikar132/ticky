import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/widgets/floating_nav_bar.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';
import 'package:ticky/features/settings/widgets/appearance_section.dart';
import 'package:ticky/features/settings/widgets/categories_section.dart';
import 'package:ticky/features/settings/widgets/history_section.dart';
import 'package:ticky/features/settings/widgets/notifications_section.dart';
import 'package:ticky/features/settings/widgets/routines_section.dart';
import 'package:ticky/features/settings/widgets/ticky_shop_section.dart';

/// Everything you can change: notifications, routines, categories, Ticky's
/// pose, and a read-only look at past days. One scrolling page; sheets do the
/// editing.
///
/// Appearance (system, light or dark) is the first section.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
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

  /// The user may have changed notification permission in system settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationPermissionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg + 4,
          0,
          AppSpacing.lg + 4,
          FloatingNavBar.reservedHeight + AppSpacing.xl,
        ),
        children: [
          const AppearanceSection(),
          const NotificationsSection(),
          const RoutinesSection(),
          const CategoriesSection(),
          const TickyShopSection(),
          const HistorySection(),
        ],
      ),
    );
  }
}
