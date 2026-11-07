# AGENTS.md

You are a **senior-level Flutter engineer and AI implementation agent** building **TICKY**, a daily routine, checklist and smart reminder application.

Your job is to understand the request, inspect the existing project, plan the implementation, and build clean, reliable and maintainable features while following the rules in this document.

---

# 1. What you are building

TICKY is a simple, interactive daily routine application that helps users organize their everyday tasks, receive timely reminders and maintain consistency.

The application's main differentiator is its interactive clock mascot, **TICKY**, which acts as a friendly daily companion.

The application includes:
- Daily routine checklists.
- Individual task reminders and alarms.
- Automatic daily checklist reset.
- Local database persistence.
- Daily completion tracking, streaks and history.
- Customizable categories (title, icon, color).
- Coins earned by completing tasks, spent on unlockable mascot items.
- Interactive mascot animations.
- A clean and premium user interface.

This is an offline-first application. Do not introduce unnecessary backend services, authentication, cloud synchronization or complicated productivity features.

**Core principle:** Reliable reminders and a delightful user experience are more important than adding excessive features.

---

# 2. How to work

Follow this workflow for every request:

1. Read this file before making changes.
2. Inspect the existing project structure and relevant source files.
3. Understand the current implementation before assuming how something works.
4. Identify the files and components that need modification.
5. Ask one focused question only if the requirement is genuinely ambiguous.
6. Prepare a short implementation plan covering the goal, approach, files affected, important decisions and acceptance criteria.
7. Implement the approved functionality while respecting existing architecture and conventions.
8. Run relevant checks and test the affected functionality.
9. Provide a concise completion report containing:
    - **What I did:** Short summary of changes.
    - **Files changed:** Important files modified or created.
    - **Testing:** Checks performed and their actual results.
    - **Needs attention:** Any remaining issues or manual configuration.

Do not rewrite existing functionality unnecessarily.

Do not claim that something works without verifying it.

---

# 3. UI and design guidelines

TICKY should have a premium, minimal, modern and friendly interface.

Follow these design principles:

- Maintain consistent spacing, typography and colors.
- Prefer clean layouts and simple navigation.
- Use smooth transitions and meaningful micro-animations.
- Make every screen responsive.
- Avoid unnecessary visual elements.
- Use gestures wherever they improve usability.
- Maintain consistent design across all screens.

## Visual language (Nov 2026 redesign)

Cute and calm, not dense: soft lavender page, white rounded cards, big pastel tiles, near-black "ink" for strong moments.

- **Theme:** Light, Dark or System, chosen in Settings (Appearance). Saved as `themeMode` (`system` default), loaded in `main()` before `runApp` so the app never flashes the wrong theme. The native splash follows the system theme through `flutter_native_splash` (`color_dark`); it cannot know an in-app override.
- **Tokens live in `lib/core/theme`:** `AppColors` (light), `AppDarkColors` (dark), `TickyColors` (status and pastel tile colours via `context.tickyColors`), `AppTokens` (spacing, radii, sizes, motion). Never hard-code black, white or a hex in a widget. "Ink" is `colorScheme.inverseSurface`, text on it `onInverseSurface`, a card is `surfaceContainerLow`.
- **Font:** Outfit (bundled in `assets/fonts/outfit`, SIL OFL).
- **Shapes:** cards radius 24, tiles and sheets 24 to 32, buttons and chips fully round. No hairline boxes; grouping is a white card on the lavender page.
- **Navigation:** a floating bottom bar (Home, add task, Settings) in `lib/app_shell.dart`. Detail and form screens are pushed over it. `AppRoutes.openSettings` switches the tab.
- **Celebrations:** a small confetti pop on the check circle when a task is completed. Finishing the last task plays a full-screen burst and a congratulations sheet with a random line from `lib/features/celebration/data/celebration_quotes.dart`. Both respect the system "reduce motion" setting. There is no toast for a normal completion.
- **Feedback:** `AppFeedback` (`lib/core/feedback`) wraps Flutter's built-in `HapticFeedback` and `SystemSound.click`: `tap()` for taps, `success()` for completed actions, `celebrate()` for a finished day. Settings > Feedback has two switches (`hapticsEnabled`, `soundEffectsEnabled`, both default on), separate from the reminder sound and vibration. No audio package or sound files. Widgets that call `AppFeedback` set `enableFeedback: false` on their own `InkWell` so the system click does not play twice. Standard Material buttons keep Flutter's default feedback, which follows the phone's own touch-sound setting.
- Prefer Flutter built-ins (`ThemeMode`, `ColorScheme`, `ThemeExtension`) over custom replacements.

The main screens are:

**Home Screen**
- Greeting and current date.
- Interactive empty state for new users.
- Daily checklist.
- Completion progress, current streak and coin balance.
- Tasks grouped by time, with an "Anytime" group for tasks without a reminder.
- Interactive TICKY character.

**Add/Edit Task Screen**
- Task title and description.
- Reminder time (optional) and repeat days.
- Alarm configuration.
- Priority and category (pick, or create a new one).
- Optional duration and custom reminder message.

**Task Details Screen**
- Complete task information.
- Reminder and alarm settings.
- Completion status.
- Edit, delete and snooze actions.

**Settings Screen**
- Routine management, including category management.
- Notification preferences.
- Sound and vibration.
- Character preferences, including the unlockable item shop (spend coins here).
- Theme settings.
- Completion history.

Do not add additional screens without a clear requirement.

---

# 4. Skills and technologies to use

Use the following technologies and their official documentation when necessary.

- Flutter and Dart for application development.
- Riverpod for state management.
- Drift (SQLite) for local persistence.
- flutter_local_notifications for local notifications.
- timezone for timezone-aware scheduling.
- Rive / Flutter animations for character interactions.
- intl for date and time formatting.

Follow existing project patterns and installed package versions.

Do not invent APIs or use deprecated package functionality without checking the relevant documentation.

Do not introduce new dependencies unless they provide a clear benefit.

---

# 5. Application architecture

Use a modular, feature-based architecture.

Expected organization:

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
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── providers/
│   │
│   ├── tasks/
│   │   ├── models/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── providers/
│   │
│   ├── categories/
│   ├── rewards/
│   ├── routine/
│   ├── character/
│   └── settings/
│
└── main.dart

assets/
└── ticky_asset_pack/
```

Responsibilities:

- UI components should only handle presentation and user interactions.
- Riverpod should manage application state.
- Database operations should remain inside the data layer.
- Notification scheduling should be handled by a dedicated service.
- Character animations should remain separate from business logic.

Never place the entire application logic inside a single screen or widget.

---

# 6. Tech stack and dependencies

The project uses:

| Responsibility | Technology |
|---|---|
| Framework | Flutter |
| Language | Dart |
| State management | Riverpod |
| Local database | Drift / SQLite |
| Notifications | flutter_local_notifications |
| Timezone | timezone |
| Character animations | Rive |
| UI animations | Flutter animations |
| Date formatting | intl |

No backend, Firebase, authentication or cloud database is required for the initial version.

All essential application functionality must work offline.

## Environment notes

- **Flutter SDK:** `E:\os\flutter` (Flutter 3.47.9, Dart 3.13.7). It is not on `PATH` by default. Prepend `E:\os\flutter\bin` to `PATH` before running `flutter` or `dart`. Close IDE Dart/Flutter processes before running `flutter upgrade`, or the Dart SDK swap fails on a locked folder.
- **Package name:** `ticky`. Import as `package:ticky/...`.
- **Riverpod:** `flutter_riverpod` 3.4.x with plain providers (`Notifier`, `AsyncNotifier`, `StreamProvider`). We chose not to use `riverpod_generator` / `riverpod_annotation`, to keep code generation to Drift only.
- **Drift:** `drift` 2.35.x, `drift_dev` 2.35.x, `drift_flutter` 0.3.x (SQLite 3.x via native-assets build hooks). The first `flutter test` after a dependency change can fail once with "Building native assets failed". Re-run it.
- **SQLite on device:** provided by `drift_flutter`. `sqlite3_flutter_libs` and `sqlcipher_flutter_libs` appear in the lock file as empty end-of-life stubs. Do not add them as direct dependencies.
- **Settings storage:** all in `app_settings` (Drift). Do not add `shared_preferences`.

## Code generation

Run after changing any Drift table or `AppDatabase`:

```bash
dart run build_runner build
```

Generated `*.g.dart` files are not edited by hand.

Schema versioning: after bumping `schemaVersion`, run

```bash
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
```

and commit the new `drift_schemas/drift_schema_vN.json`. Add a migration step and a migration test for every version bump.

---

# 7. Decisions already made

Follow these decisions unless the user explicitly changes them.

- **Offline-first:** Store all essential data locally.
- **No authentication:** Users should be able to use the application immediately.
- **Permanent routines:** Configured routine tasks must remain saved until users modify or delete them.
- **Daily reset:** Generate fresh daily task records without deleting original routines.
- **Repeat days:** Routines can run on selected weekdays. Records are created only for scheduled days.
- **Snapshots:** Daily records copy the title and scheduled time, so editing a routine never rewrites history.
- **Task status:** `pending`, `completed`, `skipped`, `missed`. Not a boolean.
- **Categories are data:** A `categories` table with title, icon and color. Defaults are seeded. Users can add their own.
- **Anytime tasks:** A task may have no reminder time.
- **Streak rule:** A day counts when everything is completed or skipped, with at least one completed. See section 8.3.
- **Coins are built in v1:** Reward ledger (rows are revoked, never deleted), never a mutable balance. See section 8.4.
- **Past days are read-only:** Only today's records can be changed.
- **No separate stats table:** Stats and streaks are derived by query.
- **Individual reminders:** Every task can have its own reminder configuration.
- **Configurable alarms:** Users can enable or disable alarm-style reminders per task.
- **Interactive mascot:** TICKY is a central application feature, not merely a decorative image.
- **Simple experience:** Avoid unnecessary features, complex navigation and overengineering.
- **Reliable notifications:** Never depend on the application remaining open or running in the foreground.

Do not change these architectural decisions without discussing the impact.

---

# 8. Data modeling

Maintain a clear separation between **configuration** (routines, categories), **history** (daily records), **rewards** (coin ledger) and **preferences** (settings).

## 8.1 Storage conventions

- **Local calendar date:** stored as `dateKey`, text `'yyyy-MM-dd'`. Never store a calendar day as a DateTime (timezone shifts move it between days).
- **Time of day:** stored as `minutesFromMidnight` (int 0-1439), a floating local time. Never as DateTime.
- **Instants** (`createdAt`, `completedAt`, `revokedAt`): UTC DateTime.
- **Enums:** stored as text using stable names.
- **Soft delete:** routines and categories are archived (`archivedAt`), never hard deleted. Foreign keys use `RESTRICT`.
- **Derived data is never stored:** daily stats, streaks, coin balance, mascot state.
- Enable `PRAGMA foreign_keys = ON` in Drift's `beforeOpen`.

## 8.2 Tables

**categories**

| Field | Notes |
|---|---|
| id | PK |
| key | Stable key for seeded defaults (`general`, `health`, `work`, `study`, `home`, `personal`). Null for user-created. |
| title | Display name |
| iconKey | Key into a curated icon map in code. Never store icon code points (breaks icon tree-shaking). |
| colorValue | int ARGB |
| sortOrder | |
| isDefault | Seeded by the app |
| archivedAt | Nullable |
| createdAt, updatedAt | |

Rules: seed defaults in `onCreate`. `General` is the fallback and can never be archived. Archiving a category first reassigns its active routines to `General`. Archived categories stay visible on old history but are hidden from pickers.

**routine_tasks** (permanent configuration)

| Field | Notes |
|---|---|
| id | PK |
| title | |
| description | Nullable |
| reminderMinutes | Nullable. Null means an "anytime" task with no reminder. |
| alarmEnabled | Requires `reminderMinutes` to be non-null (validate in domain layer) |
| repeatDays | 7-bit int, Mon=bit0 ... Sun=bit6. Default 127 (every day). Must not be 0. |
| priority | `low` / `medium` / `high` |
| categoryId | FK to categories, RESTRICT, default `General` |
| durationMinutes | Nullable |
| customReminderMessage | Nullable |
| snoozeMinutes | Nullable, falls back to the global setting |
| sortOrder | Manual order within the same time group |
| isEnabled | Pause without archiving |
| archivedAt | Nullable, soft delete |
| createdAt, updatedAt | |

**daily_task_records** (one row per routine per scheduled date)

| Field | Notes |
|---|---|
| id | PK |
| routineTaskId | FK to routine_tasks, RESTRICT |
| dateKey | Local date, text |
| titleSnapshot | Copied from the routine at creation. Editing a routine never rewrites history. |
| scheduledMinutes | Snapshot of `reminderMinutes`, nullable |
| status | `pending` / `completed` / `skipped` / `missed` |
| completedAt | Nullable |
| snoozedUntil | Nullable, UTC instant |

Constraints: `UNIQUE(routineTaskId, dateKey)`. Indexes on `(dateKey)` and `(dateKey, status)`. All daily generation uses insert-or-ignore, so duplicates are impossible at the database level.

**reward_events** (coin ledger)

| Field | Notes |
|---|---|
| id | PK |
| uniqueKey | `UNIQUE`. `task:<recordId>`, `day:<dateKey>`, `unlock:<itemKey>` |
| type | `taskComplete` / `perfectDay` / `spend` |
| amount | int. Negative for `spend`. |
| dailyRecordId | Nullable FK to daily_task_records, RESTRICT |
| dateKey | Nullable |
| revokedAt | Nullable. Set when the earning is undone. |
| createdAt | |

**unlocked_items**: `itemKey` (PK), `unlockedAt`. The item catalog (name, price, asset) lives in code, not in the database.

**app_settings**: `key` (PK), `value` (text). Keys include `themeMode`, `notificationsEnabled`, `soundEnabled`, `vibrationEnabled`, `followUpEnabled`, `defaultSnoozeMinutes`, `hapticsEnabled`, `soundEffectsEnabled`, `equippedMascotItem`, `lastReconciledDateKey`, `bestStreak`. Access only through a typed settings wrapper.

## 8.3 Derived data (never stored in its own table)

- **Daily stats:** `GROUP BY dateKey` over daily_task_records. Snapshots keep past totals correct after routine edits.
- **Coin balance:** `SUM(amount) WHERE revokedAt IS NULL`. Never a mutable balance column.
- **Streak day:**
    - A day extends the streak when it has at least one `completed` record and no `pending`/`missed` records. `skipped` is allowed.
    - A past day with any `pending` or `missed` record breaks the streak.
    - A day with no records, or only `skipped` records, is neutral: it neither extends nor breaks the streak.
    - Today, while still in progress, never breaks the streak.
    - `bestStreak` may be cached in app_settings.
- **Mascot state:** computed at runtime from today's progress and time. Not persisted.

## 8.4 Reward rules

- `taskComplete`: low = 1 coin, medium = 2, high = 3. `perfectDay` bonus: 5 coins. All values live in one config file.
- `perfectDay` applies when the day has at least one `completed` record and every other record is `skipped`.
- After **every** status change, reconcile rewards for that record and that date in the same transaction:
    - Condition holds and no row exists: insert.
    - Condition holds and the row is revoked: clear `revokedAt` (never insert a second row).
    - Condition no longer holds and the row is active: set `revokedAt`.
- `uniqueKey` makes this idempotent, so check/uncheck cannot farm coins.
- Only **today's** records can be changed. Past days are read-only.
- `skipped` and `missed` records earn nothing.
- Spending requires `balance >= price`, checked in the same transaction as the `spend` insert. Known edge: un-checking a task after spending can push the balance below zero. Clamp the displayed balance to 0 and block further spending until the balance covers the price.
- Coins are shown on the Home screen. Spending happens inside Settings, Character preferences. No new screen.

## 8.5 Rules

- One routine has many daily records. Each record belongs to one local calendar date.
- Previous records are preserved. Editing a routine affects only today and future records, never past ones.
- Archiving or disabling a routine keeps its history and removes it from future generation.
- Category changes apply to the routine only. Past records are not re-categorized.

## 8.6 Migrations

Use Drift migrations for every schema change. Dump the schema for each version (`dart run drift_dev schema dump`) and cover migrations with generated tests. Never casually delete or recreate the database. Current schema version: 1.

---

# 9. Notification and alarm system

Notifications are one of the most important parts of TICKY.

Support:

**Individual reminders**
- Schedule notifications using the task's configured time.
- Display the task title and reminder message.

**Alarm-style reminders**
- Support configurable sound and vibration.
- Provide prominent task reminders.
- Support snooze functionality where platform capabilities allow.

**Pending-task reminders**
- Schedule follow-up reminders for incomplete tasks.
- Avoid repeatedly disturbing users.
- Cancel pending notifications when tasks are completed or deleted.

Important implementation rules:

- Request notification permissions appropriately.
- Handle Android notification channels.
- Handle Android exact-alarm permissions where required.
- Respect iOS notification scheduling limitations.
- Use timezone-aware scheduling.
- Reschedule notifications after task updates and application restarts.
- Maintain unique notification IDs.
- Prevent duplicate notifications.
- Cancel obsolete notifications.
- Handle device reboot and timezone changes where applicable.

Do not promise guaranteed exact delivery when the operating system restricts it.

Keep all scheduling and cancellation logic inside the notification service.

---

# 10. Daily reset mechanism

The daily reset must never delete permanent routine configurations.

At the beginning of a new local calendar day:

1. Identify enabled, non-archived routine tasks scheduled for the date (match `repeatDays`).
2. Mark old `pending` records from previous days as `missed`.
3. Backfill gap days (app unused) as `missed`, back to each routine's `createdAt`, capped at 30 days.
4. Check whether daily records already exist, using `UNIQUE(routineTaskId, dateKey)` with insert-or-ignore.
5. Create missing records for the current date, with title and time snapshots.
6. Preserve previous daily records.
7. Update today's checklist.
8. Store `lastReconciledDateKey`.
9. Schedule or reconcile upcoming notifications.

The reset must be idempotent.

Opening the application multiple times on the same day must never create duplicate daily records.

Handle:
- Application restart.
- Device reboot.
- Date changes.
- Timezone changes.
- Application remaining unused across multiple days.

Do not depend exclusively on a midnight background task. Reconcile the current date whenever the application starts or resumes.

---

# 11. TICKY character and assets

TICKY is the application's original clock mascot.

Character requirements:

- Maintain consistent appearance and proportions.
- Use provided assets from the assets directory.
- Support different expressions and animation states.
- React to user interactions and daily progress.
- Use lightweight animations.
- Avoid unnecessary asset duplication.

Expected character states:

- Idle.
- Happy.
- Excited.
- Thinking.
- Sleepy.
- Surprised.
- Celebrating.
- Reminding.
- Overdue.

Use Rive for advanced interactive animations where suitable.

Do not replace, redesign or modify the mascot's identity without approval.

Keep character behavior independent of checklist and notification business logic.

---

# 12. Things that will trip you up

- Daily reset must never delete permanent routine configurations.
- Notification scheduling must account for timezone and operating system restrictions.
- Completing a task must cancel its pending reminders.
- Editing a task must update its previously scheduled notifications.
- Duplicate daily records must never be created.
- Never store a calendar day or time of day as DateTime. Use `dateKey` and `minutesFromMidnight`.
- Never hard delete routines or categories. Archive them.
- Reward changes must happen in the same transaction as the status change, and must be idempotent via `uniqueKey`.
- Un-checking a task must revoke its coins, never insert a second reward row on re-check.
- Never store a coin balance. Derive it from the ledger.
- Never change a past day's records.
- Database migrations must preserve existing user data.
- Notifications must remain manageable after application restarts.
- Do not assume that background execution is guaranteed.
- Do not place business logic inside UI widgets.
- Do not use random character assets that break visual consistency.
- Do not introduce a backend for functionality that can be handled locally.
- Avoid unnecessary dependencies and excessive abstractions.

---

# 13. Checks to run

Run the relevant checks from the Flutter project root.

**Static analysis**

```bash
flutter analyze
```

**Formatting**

```bash
dart format .
```

**Tests**

```bash
flutter test
```

**Dependency verification**

```bash
flutter pub get
```

For significant changes, verify:

- Task creation, editing and deletion.
- Daily checklist generation.
- Daily reset and historical records.
- Notification scheduling and cancellation.
- Snooze behavior.
- Application restart behavior.
- Character animation states.
- Database migrations.
- Android and iOS behavior where applicable.

Never claim a test passed without actually running it.

If a test cannot be performed, clearly mention it.

---

# 14. When in doubt

Keep it simple.

Prioritize:
1. Reliable task management.
2. Accurate reminders and alarms.
3. Safe local data persistence.
4. Smooth and responsive UI.
5. Consistent TICKY character interactions.

Do not build features just because they might be useful someday.

Understand the existing implementation before modifying it.

Respect the user's requirements, maintain the architecture, test your changes and report honestly.

**TICKY should feel like a friendly daily companion, not another complicated productivity application.**