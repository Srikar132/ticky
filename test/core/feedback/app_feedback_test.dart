import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/feedback/app_feedback.dart';

import '../../support/feedback_log.dart';

void main() {
  testWidgets('a tap is a light buzz and the system click', (tester) async {
    final log = FeedbackLog(tester);

    AppFeedback.tap();

    expect(log.calls, [
      'haptic:HapticFeedbackType.selectionClick',
      'sound:SystemSoundType.click',
    ]);
  });

  testWidgets('success is a firmer buzz and the click', (tester) async {
    final log = FeedbackLog(tester);

    AppFeedback.success();

    expect(log.calls, [
      'haptic:HapticFeedbackType.mediumImpact',
      'sound:SystemSoundType.click',
    ]);
  });

  testWidgets('celebrating buzzes firmly, then softer', (tester) async {
    final log = FeedbackLog(tester);

    final done = AppFeedback.celebrate();
    await tester.pump(const Duration(milliseconds: 300));
    await done;

    expect(log.haptics, [
      'haptic:HapticFeedbackType.heavyImpact',
      'haptic:HapticFeedbackType.mediumImpact',
    ]);
    expect(log.sounds, ['sound:SystemSoundType.click']);
  });

  testWidgets('with haptics off only the click plays', (tester) async {
    final log = FeedbackLog(tester);
    AppFeedback.configure(haptics: false, sounds: true);

    AppFeedback.tap();
    AppFeedback.success();
    await AppFeedback.celebrate();

    expect(log.haptics, isEmpty);
    expect(log.sounds, hasLength(3));
  });

  testWidgets('with sounds off only the buzz plays', (tester) async {
    final log = FeedbackLog(tester);
    AppFeedback.configure(haptics: true, sounds: false);

    AppFeedback.tap();
    AppFeedback.success();

    expect(log.sounds, isEmpty);
    expect(log.haptics, hasLength(2));
  });

  testWidgets('with both off it is silent and still', (tester) async {
    final log = FeedbackLog(tester);
    AppFeedback.configure(haptics: false, sounds: false);

    AppFeedback.tap();
    AppFeedback.success();
    await AppFeedback.celebrate();

    expect(log.calls, isEmpty);
  });

  testWidgets('switching haptics off mid-celebration stops the second buzz', (
    tester,
  ) async {
    final log = FeedbackLog(tester);

    final done = AppFeedback.celebrate();
    await tester.pump(const Duration(milliseconds: 10));
    AppFeedback.configure(haptics: false, sounds: true);
    await tester.pump(const Duration(milliseconds: 300));
    await done;

    expect(log.haptics, ['haptic:HapticFeedbackType.heavyImpact']);
  });
}
