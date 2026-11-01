# TICKY ⏰

**Your Daily Companion**

TICKY is a simple, interactive daily routine and checklist application built with Flutter. It helps users organize their daily tasks, stay consistent with their routines, and never miss important activities through smart reminders and alarm notifications.

## ✨ Features

- **Daily Checklist:** Create and manage your everyday tasks.
- **Smart Reminders:** Get notifications for scheduled tasks.
- **Task Alarms:** Set individual alarms for important activities.
- **Daily Reset:** Automatically generate a fresh checklist every day while preserving your routine.
- **Task Management:** Add, edit, delete and mark tasks as completed.
- **Interactive Character:** Meet TICKY, a friendly animated clock companion that reacts to your progress.
- **Progress Tracking:** Monitor daily task completion.
- **Offline Support:** Store routines and task records locally.

## 🛠️ Tech Stack

- Flutter & Dart
- Riverpod – State Management
- Drift (SQLite) – Local Database
- Flutter Local Notifications – Reminders
- Rive / Flutter Animations – Character Animations
- Timezone – Reminder Scheduling

## 📱 Main Screens

1. **Home:** Daily checklist, progress and interactive character.
2. **Add Task:** Configure task details, reminders and alarms.
3. **Task Details:** View and manage individual tasks.
4. **Settings:** Manage notifications, preferences and routines.

## 📂 Project Structure

```text
lib/
├── core/
│   ├── database/
│   ├── notifications/
│   ├── theme/
│   └── utils/
│
├── features/
│   ├── home/
│   ├── tasks/
│   ├── routine/
│   ├── character/
│   └── settings/
│
└── main.dart

assets/
└── ticky_asset_pack/
```

## 🚀 Getting Started

Clone the repository:

```bash
git clone <repository-url>
```

Navigate to the project:

```bash
cd ticky
```

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

## 🎯 Project Goal

TICKY aims to make daily task management simple, enjoyable and consistent. Instead of being just another checklist application, it acts as a friendly daily companion that reminds, motivates and celebrates users throughout their day.

**Stay consistent. Complete your day. Let TICKY remind you!** ⏰