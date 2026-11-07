import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/widgets/floating_nav_bar.dart';
import 'package:ticky/features/home/screens/home_screen.dart';
import 'package:ticky/features/settings/screens/settings_screen.dart';

/// The two root tabs.
enum MainTab { home, settings }

/// Which root tab is showing. Set it to switch tabs from anywhere.
final mainTabProvider = NotifierProvider<MainTabController, MainTab>(
  MainTabController.new,
);

class MainTabController extends Notifier<MainTab> {
  @override
  MainTab build() => MainTab.home;

  void select(MainTab tab) => state = tab;
}

/// The app's root: Home and Settings behind a floating bottom bar. Both tabs
/// stay alive, so scroll position and open state survive switching. Detail and
/// edit screens are pushed on top and cover the bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(mainTabProvider);
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: tab.index,
        children: const [HomeScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: FloatingNavBar(
        left: const NavDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Home',
        ),
        right: const NavDestination(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
          label: 'Settings',
        ),
        selectedIndex: tab.index,
        onSelected: (i) =>
            ref.read(mainTabProvider.notifier).select(MainTab.values[i]),
        onAdd: () => AppRoutes.openAddTask(context),
      ),
    );
  }
}
