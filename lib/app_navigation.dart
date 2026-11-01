import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Handles to the app's navigator and snack bar host, for code that reacts to
/// something outside the widget tree, such as a tapped notification.
class AppNavigation {
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
}

final appNavigationProvider = Provider<AppNavigation>((ref) => AppNavigation());
