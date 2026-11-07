import 'package:flutter/foundation.dart';

/// The two switches for Ticky's own taps and celebration feedback. These are
/// separate from the reminder sound and vibration in [NotificationPrefs].
@immutable
class FeedbackPrefs {
  const FeedbackPrefs({this.haptics = true, this.sounds = true});

  final bool haptics;
  final bool sounds;

  FeedbackPrefs copyWith({bool? haptics, bool? sounds}) => FeedbackPrefs(
    haptics: haptics ?? this.haptics,
    sounds: sounds ?? this.sounds,
  );

  @override
  bool operator ==(Object other) =>
      other is FeedbackPrefs &&
      other.haptics == haptics &&
      other.sounds == sounds;

  @override
  int get hashCode => Object.hash(haptics, sounds);
}
