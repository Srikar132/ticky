import 'package:ticky/features/focus/models/focus_block.dart';
import 'package:ticky/features/focus/models/focus_markdown.dart';

/// "Bring yesterday's focus over?" The facts shown in that offer.
class CarryOffer {
  const CarryOffer({
    required this.sourceDateKey,
    required this.body,
    required this.goals,
    required this.unfinished,
  });

  factory CarryOffer.fromBody(String sourceDateKey, String body) {
    final progress = FocusProgress.of(parseFocusMarkdown(body));
    return CarryOffer(
      sourceDateKey: sourceDateKey,
      body: body,
      goals: progress.total,
      unfinished: progress.total - progress.done,
    );
  }

  /// The day the offer comes from, `yyyy-MM-dd`.
  final String sourceDateKey;

  /// That day's saved markdown.
  final String body;

  /// To-dos on that day, and how many were left undone.
  final int goals;
  final int unfinished;

  /// Some goals were done and some were not, so "unfinished only" differs from
  /// "everything".
  bool get hasMixedProgress =>
      goals > 0 && unfinished > 0 && unfinished < goals;
}
