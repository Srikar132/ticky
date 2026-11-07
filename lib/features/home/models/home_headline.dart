import 'package:ticky/features/home/models/daily_progress.dart';

/// The big title at the top of Home, chosen from today's progress.
String homeHeadline(DailyProgress progress, {required bool hasRoutines}) {
  if (progress.isEmpty) {
    return hasRoutines ? 'A free day.' : 'Let’s build your day.';
  }
  if (progress.allDone) return 'Perfect day!';
  if (progress.allSkipped) return 'Nothing left today.';
  if (progress.completed == 0) return 'Start today’s tasks.';
  if (progress.remaining == 1) return 'Just one to go.';
  return 'Keep it going.';
}
