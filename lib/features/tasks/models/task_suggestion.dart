import 'package:flutter/material.dart';

/// A ready-made starting point shown to new users. Tapping one opens the new
/// task form already filled in.
class TaskSuggestion {
  const TaskSuggestion({
    required this.title,
    required this.reminderMinutes,
    required this.icon,
  });

  final String title;

  /// Suggested reminder time, minutes from midnight.
  final int reminderMinutes;
  final IconData icon;
}

const taskSuggestions = <TaskSuggestion>[
  TaskSuggestion(
    title: 'Drink water',
    reminderMinutes: 8 * 60,
    icon: Icons.water_drop_outlined,
  ),
  TaskSuggestion(
    title: 'Morning stretch',
    reminderMinutes: 7 * 60 + 30,
    icon: Icons.self_improvement,
  ),
  TaskSuggestion(
    title: 'Plan my day',
    reminderMinutes: 9 * 60,
    icon: Icons.edit_calendar_outlined,
  ),
  TaskSuggestion(
    title: 'Read 10 minutes',
    reminderMinutes: 21 * 60,
    icon: Icons.menu_book_outlined,
  ),
];
