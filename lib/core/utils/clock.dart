import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of "now". Injected so tests can control time.
typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);
