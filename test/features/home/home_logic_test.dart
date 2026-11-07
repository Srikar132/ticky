import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/features/home/models/home_headline.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/features/character/models/mascot_mood.dart';
import 'package:ticky/features/home/models/daily_progress.dart';
import 'package:ticky/features/home/models/day_phase.dart';
import 'package:ticky/features/home/models/task_group.dart';
import 'package:ticky/features/routine/models/streak.dart';

import '../../support/home_test_support.dart';

DayTally day(String key, {int completed = 0, int open = 0}) =>
    DayTally(dateKey: key, completed: completed, open: open);

MascotMood mood({
  bool hasRoutines = true,
  bool hasTasksToday = true,
  int completed = 0,
  double progress = 0,
  bool allDone = false,
  bool anyOverdue = false,
  bool dueSoon = false,
  int hour = 10,
}) => mascotMoodFor(
  hasRoutines: hasRoutines,
  hasTasksToday: hasTasksToday,
  completed: completed,
  progress: progress,
  allDone: allDone,
  anyOverdue: anyOverdue,
  dueSoon: dueSoon,
  hour: hour,
);

void main() {
  group('computeStreak', () {
    test('counts consecutive fully done days', () {
      final info = computeStreak([
        day('2026-11-01', completed: 2),
        day('2026-11-02', completed: 1),
        day('2026-11-03', completed: 3),
      ], '2026-11-03');

      expect(info.count, 3);
      expect(info.includesToday, isTrue);
    });

    test('today in progress does not count and does not break', () {
      final info = computeStreak([
        day('2026-11-01', completed: 1),
        day('2026-11-02', completed: 1),
        day('2026-11-03', completed: 1, open: 1),
      ], '2026-11-03');

      expect(info.count, 2);
      expect(info.includesToday, isFalse);
    });

    test('a past day with pending or missed work breaks the streak', () {
      final info = computeStreak([
        day('2026-10-30', completed: 1),
        day('2026-10-31', completed: 1),
        day('2026-11-01', completed: 1, open: 1),
        day('2026-11-02', completed: 1),
      ], '2026-11-03');

      expect(info.count, 1);
    });

    test('a day with only skipped records is neutral', () {
      final info = computeStreak([
        day('2026-11-01', completed: 1),
        day('2026-11-02'),
        day('2026-11-03', completed: 1),
      ], '2026-11-03');

      expect(info.count, 2);
    });

    test('days without records are neutral', () {
      final info = computeStreak([
        day('2026-10-20', completed: 1),
        day('2026-11-03', completed: 1),
      ], '2026-11-03');

      expect(info.count, 2);
    });

    test('ignores future days and unsorted input', () {
      final info = computeStreak([
        day('2026-11-05', completed: 1),
        day('2026-11-02', completed: 1),
        day('2026-11-01', completed: 1),
      ], '2026-11-02');

      expect(info.count, 2);
    });

    test('empty history is no streak', () {
      expect(computeStreak(const [], '2026-11-02'), StreakInfo.none);
    });
  });

  group('DailyProgress', () {
    test('skipped tasks do not count against the day', () {
      final progress = DailyProgress.fromEntries([
        entry(id: 1, status: TaskStatus.completed),
        entry(id: 2, status: TaskStatus.skipped),
        entry(id: 3, status: TaskStatus.pending),
      ]);

      expect(progress.total, 3);
      expect(progress.target, 2);
      expect(progress.completed, 1);
      expect(progress.remaining, 1);
      expect(progress.fraction, 0.5);
      expect(progress.allDone, isFalse);
    });

    test('allDone needs at least one completed task', () {
      final done = DailyProgress.fromEntries([
        entry(id: 1, status: TaskStatus.completed),
        entry(id: 2, status: TaskStatus.skipped),
      ]);
      final allSkipped = DailyProgress.fromEntries([
        entry(id: 1, status: TaskStatus.skipped),
      ]);

      expect(done.allDone, isTrue);
      expect(allSkipped.allDone, isFalse);
      expect(allSkipped.allSkipped, isTrue);
      expect(allSkipped.fraction, 0);
    });

    test('empty day', () {
      final progress = DailyProgress.fromEntries(const []);

      expect(progress.isEmpty, isTrue);
      expect(progress.fraction, 0);
    });
  });

  group('overdue and due soon', () {
    final at9 = DateTime(2026, 11, 2, 9);

    test('a pending timed task in the past is overdue', () {
      expect(isOverdue(entry(id: 1, minutes: 8 * 60), at9), isTrue);
    });

    test('not overdue: future, completed, skipped or anytime', () {
      expect(isOverdue(entry(id: 1, minutes: 10 * 60), at9), isFalse);
      expect(
        isOverdue(
          entry(id: 1, minutes: 8 * 60, status: TaskStatus.completed),
          at9,
        ),
        isFalse,
      );
      expect(
        isOverdue(
          entry(id: 1, minutes: 8 * 60, status: TaskStatus.skipped),
          at9,
        ),
        isFalse,
      );
      expect(isOverdue(entry(id: 1), at9), isFalse);
    });

    test('due soon means a pending task within 30 minutes', () {
      expect(hasDueSoon([entry(id: 1, minutes: 9 * 60 + 20)], at9), isTrue);
      expect(hasDueSoon([entry(id: 1, minutes: 9 * 60)], at9), isTrue);
      expect(hasDueSoon([entry(id: 1, minutes: 10 * 60)], at9), isFalse);
      expect(hasDueSoon([entry(id: 1, minutes: 8 * 60)], at9), isFalse);
    });
  });

  group('groupEntriesByTime', () {
    test('buckets by time of day with Anytime last, skipping empty groups', () {
      final groups = groupEntriesByTime([
        entry(id: 1, minutes: 7 * 60),
        entry(id: 2, minutes: 11 * 60 + 59),
        entry(id: 3, minutes: 12 * 60),
        entry(id: 4, minutes: 19 * 60),
        entry(id: 5, minutes: 22 * 60),
        entry(id: 6),
      ]);

      expect(groups.map((g) => g.kind), [
        TaskGroupKind.morning,
        TaskGroupKind.afternoon,
        TaskGroupKind.evening,
        TaskGroupKind.night,
        TaskGroupKind.anytime,
      ]);
      expect(groups.first.entries.map((e) => e.record.id), [1, 2]);
    });

    test('boundaries: 17:00 is evening, 21:00 is night', () {
      expect(TaskGroupKind.forMinutes(16 * 60 + 59), TaskGroupKind.afternoon);
      expect(TaskGroupKind.forMinutes(17 * 60), TaskGroupKind.evening);
      expect(TaskGroupKind.forMinutes(20 * 60 + 59), TaskGroupKind.evening);
      expect(TaskGroupKind.forMinutes(21 * 60), TaskGroupKind.night);
      expect(TaskGroupKind.forMinutes(null), TaskGroupKind.anytime);
    });

    test('no entries, no groups', () {
      expect(groupEntriesByTime(const []), isEmpty);
    });
  });

  group('DayPhase', () {
    test('picks the header image by hour', () {
      DayPhase at(int hour) => DayPhase.at(DateTime(2026, 11, 2, hour));

      expect(at(4), DayPhase.night);
      expect(at(5), DayPhase.morning);
      expect(at(11), DayPhase.morning);
      expect(at(12), DayPhase.afternoon);
      expect(at(17), DayPhase.afternoon);
      expect(at(18), DayPhase.night);
      expect(at(23), DayPhase.night);
      expect(at(0), DayPhase.night);
    });

    test('greetings', () {
      String at(int hour) => greetingFor(DateTime(2026, 11, 2, hour));

      expect(at(8), 'Good morning');
      expect(at(13), 'Good afternoon');
      expect(at(18), 'Good evening');
      expect(at(22), 'Good night');
      expect(at(2), 'Good night');
    });
  });

  group('mascotMoodFor', () {
    test('no routines: thinking', () {
      expect(
        mood(hasRoutines: false, hasTasksToday: false),
        MascotMood.thinking,
      );
    });

    test('routines but nothing today: idle, sleepy late at night', () {
      expect(mood(hasTasksToday: false), MascotMood.idle);
      expect(mood(hasTasksToday: false, hour: 23), MascotMood.sleepy);
    });

    test('everything done: celebrating, even late at night', () {
      expect(
        mood(allDone: true, completed: 3, progress: 1),
        MascotMood.celebrating,
      );
      expect(
        mood(allDone: true, progress: 1, hour: 23),
        MascotMood.celebrating,
      );
    });

    test('overdue beats reminding, which beats progress', () {
      expect(mood(anyOverdue: true, dueSoon: true), MascotMood.overdue);
      expect(mood(dueSoon: true, progress: 0.9), MascotMood.reminding);
    });

    test('late night is sleepy, otherwise progress decides', () {
      expect(mood(hour: 23), MascotMood.sleepy);
      expect(mood(hour: 3, progress: 0.9), MascotMood.sleepy);
      expect(mood(progress: 0.5, completed: 1), MascotMood.excited);
      expect(mood(progress: 0.2, completed: 1), MascotMood.happy);
      expect(mood(), MascotMood.idle);
    });

    test('every mood has messages, and the index wraps', () {
      for (final m in MascotMood.values) {
        expect(mascotMessages[m], isNotEmpty, reason: '$m');
        expect(mascotMessage(m, 0), isNotEmpty);
        final count = mascotMessages[m]!.length;
        expect(mascotMessage(m, count), mascotMessage(m, 0));
      }
    });
  });

  group('homeHeadline', () {
    String headline(
      int completed,
      int total, {
      int skipped = 0,
      bool has = true,
    }) => homeHeadline(
      DailyProgress(total: total, completed: completed, skipped: skipped),
      hasRoutines: has,
    );

    test('a brand new user is invited to build a day', () {
      expect(headline(0, 0, has: false), 'Let’s build your day.');
    });

    test('routines that do not run today make a free day', () {
      expect(headline(0, 0), 'A free day.');
    });

    test('follows the progress through the day', () {
      expect(headline(0, 4), 'Start today’s tasks.');
      expect(headline(1, 4), 'Keep it going.');
      expect(headline(3, 4), 'Just one to go.');
      expect(headline(4, 4), 'Perfect day!');
    });

    test('skipped tasks do not hold back the perfect day', () {
      expect(headline(3, 4, skipped: 1), 'Perfect day!');
      expect(headline(0, 2, skipped: 2), 'Nothing left today.');
    });
  });
}
