import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/feedback/app_feedback.dart';

/// Records the haptics and system sounds the app asks the phone for.
///
/// Entries look like `haptic:HapticFeedbackType.selectionClick` and
/// `sound:SystemSoundType.click`. Also resets [AppFeedback] to both-on, and
/// back after the test, because it is global state.
class FeedbackLog {
  FeedbackLog(WidgetTester tester) {
    AppFeedback.configure(haptics: true, sounds: true);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'HapticFeedback.vibrate':
            calls.add('haptic:${call.arguments}');
          case 'SystemSound.play':
            calls.add('sound:${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      AppFeedback.configure(haptics: true, sounds: true);
    });
  }

  final calls = <String>[];

  Iterable<String> get haptics => calls.where((c) => c.startsWith('haptic:'));
  Iterable<String> get sounds => calls.where((c) => c.startsWith('sound:'));
}
