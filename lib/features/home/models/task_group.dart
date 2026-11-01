import 'package:flutter/material.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';

/// Checklist sections. Timed tasks fall into a part of the day; tasks without
/// a reminder time go to "Anytime".
enum TaskGroupKind {
  morning('Morning', Icons.wb_sunny_outlined),
  afternoon('Afternoon', Icons.wb_twilight),
  evening('Evening', Icons.nights_stay_outlined),
  night('Night', Icons.bedtime_outlined),
  anytime('Anytime', Icons.all_inclusive);

  const TaskGroupKind(this.label, this.icon);

  final String label;
  final IconData icon;

  static TaskGroupKind forMinutes(int? minutes) {
    if (minutes == null) return anytime;
    if (minutes < 12 * 60) return morning;
    if (minutes < 17 * 60) return afternoon;
    if (minutes < 21 * 60) return evening;
    return night;
  }
}

class TaskGroup {
  const TaskGroup(this.kind, this.entries);

  final TaskGroupKind kind;
  final List<DailyTaskEntry> entries;
}

/// Splits [entries] (already ordered by time) into non-empty groups, in day
/// order with "Anytime" last.
List<TaskGroup> groupEntriesByTime(List<DailyTaskEntry> entries) {
  final byKind = <TaskGroupKind, List<DailyTaskEntry>>{};
  for (final entry in entries) {
    byKind
        .putIfAbsent(
          TaskGroupKind.forMinutes(entry.record.scheduledMinutes),
          () => [],
        )
        .add(entry);
  }
  return [
    for (final kind in TaskGroupKind.values)
      if (byKind[kind] case final list?) TaskGroup(kind, list),
  ];
}
