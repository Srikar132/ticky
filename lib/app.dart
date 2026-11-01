import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/app_navigation.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/theme/app_theme.dart';

/// Root widget. Dark-only, so there is no theme mode to switch.
class TickyApp extends ConsumerWidget {
  const TickyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigation = ref.watch(appNavigationProvider);
    return MaterialApp(
      title: 'Ticky',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigation.navigatorKey,
      scaffoldMessengerKey: navigation.messengerKey,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
