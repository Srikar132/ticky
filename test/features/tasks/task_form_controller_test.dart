import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/notifications/notification_providers.dart';
import 'package:ticky/features/categories/providers/category_providers.dart';
import 'package:ticky/features/tasks/models/repeat_days.dart';
import 'package:ticky/features/tasks/models/routine_draft.dart';
import 'package:ticky/features/tasks/models/task_form_state.dart';
import 'package:ticky/features/tasks/models/task_suggestion.dart';
import 'package:ticky/features/tasks/providers/task_form_controller.dart';
import 'package:ticky/features/tasks/providers/task_providers.dart';

import '../../support/home_test_support.dart';
import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  late FakeNotificationService notifications;

  setUp(() {
    env = TestEnv();
    notifications = FakeNotificationService();
  });
  tearDown(() => env.close());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        routineRepositoryProvider.overrideWithValue(env.routines),
        activeCategoriesProvider.overrideWith(
          (ref) => env.categories.watchActive(),
        ),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Loads the form and keeps it alive (it is auto-disposed).
  Future<TaskFormController> openForm(
    ProviderContainer container, [
    TaskFormArgs args = const TaskFormArgs(),
  ]) async {
    final provider = taskFormControllerProvider(args);
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
    return container.read(provider.notifier);
  }

  TaskFormState formOf(
    ProviderContainer container, [
    TaskFormArgs args = const TaskFormArgs(),
  ]) => container.read(taskFormControllerProvider(args)).requireValue;

  group('opening', () {
    test('a new task starts with sensible defaults and no changes', () async {
      final container = makeContainer();
      await openForm(container);
      final form = formOf(container);

      expect(form.isEditing, isFalse);
      expect(form.values.title, '');
      expect(form.values.categoryId, await env.generalId());
      expect(form.values.repeatDays, 127);
      expect(form.values.priority, Priority.medium);
      expect(form.values.reminderMinutes, isNull);
      expect(form.isDirty, isFalse);
    });

    test(
      'a new task is ready at once when the categories are loaded',
      () async {
        final container = makeContainer();
        container.listen(activeCategoriesProvider, (_, _) {});
        await container.read(activeCategoriesProvider.future);

        const args = TaskFormArgs();
        final provider = taskFormControllerProvider(args);
        container.listen(provider, (_, _) {});

        expect(
          container.read(provider).hasValue,
          isTrue,
          reason: 'no loading frame: the form can be drawn on the first build',
        );
        expect(container.read(provider).requireValue.isDirty, isFalse);
      },
    );

    test('editing still waits for the routine to load', () async {
      final id = await env.addRoutine();
      final container = makeContainer();
      container.listen(activeCategoriesProvider, (_, _) {});
      await container.read(activeCategoriesProvider.future);

      final args = TaskFormArgs(routineId: id);
      final provider = taskFormControllerProvider(args);
      container.listen(provider, (_, _) {});

      expect(container.read(provider).hasValue, isFalse);
      await container.read(provider.future);
      expect(container.read(provider).requireValue.values.title, 'Drink water');
    });

    test('a suggestion pre-fills title and time without counting as a '
        'change', () async {
      final container = makeContainer();
      final args = TaskFormArgs(suggestion: taskSuggestions.first);
      await openForm(container, args);
      final form = formOf(container, args);

      expect(form.values.title, 'Drink water');
      expect(form.values.reminderMinutes, 8 * 60);
      expect(form.isDirty, isFalse);
    });

    test('editing loads every field of the routine', () async {
      final id = await env.routines.create(
        (await _draft(
          env,
          title: 'Stretch',
          reminderMinutes: 450,
          alarmEnabled: true,
          repeatDays: weekdaysMask,
          priority: Priority.high,
          durationMinutes: 15,
          description: 'Back and neck',
          message: 'Up you get',
          snoozeMinutes: 5,
        )),
      );
      final container = makeContainer();
      final args = TaskFormArgs(routineId: id);
      await openForm(container, args);
      final values = formOf(container, args).values;

      expect(formOf(container, args).isEditing, isTrue);
      expect(values.title, 'Stretch');
      expect(values.description, 'Back and neck');
      expect(values.reminderMinutes, 450);
      expect(values.alarmEnabled, isTrue);
      expect(values.repeatDays, weekdaysMask);
      expect(values.priority, Priority.high);
      expect(values.durationMinutes, 15);
      expect(values.customReminderMessage, 'Up you get');
      expect(values.snoozeMinutes, 5);
      expect(formOf(container, args).isDirty, isFalse);
    });

    test('editing a routine that does not exist fails cleanly', () async {
      final container = makeContainer();
      const args = TaskFormArgs(routineId: 999);
      final provider = taskFormControllerProvider(args);
      container.listen(provider, (_, _) {});

      await expectLater(
        container.read(provider.future),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('editing an archived routine fails cleanly', () async {
      final id = await env.addRoutine();
      await env.routines.archive(id);
      final container = makeContainer();
      final args = TaskFormArgs(routineId: id);
      final provider = taskFormControllerProvider(args);
      container.listen(provider, (_, _) {});

      await expectLater(
        container.read(provider.future),
        throwsA(isA<NotFoundException>()),
      );
    });

    test(
      'a category that is no longer offered falls back to General',
      () async {
        final fake = FakeRoutineRepository([routine(id: 5, categoryId: 77)]);
        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(fake),
            activeCategoriesProvider.overrideWith(
              (ref) => Stream.value([category()]),
            ),
            notificationServiceProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(container.dispose);
        const args = TaskFormArgs(routineId: 5);
        await openForm(container, args);

        expect(formOf(container, args).values.categoryId, 1);
      },
    );
  });

  group('editing the form', () {
    test(
      'changes make the form dirty, and undoing them makes it clean',
      () async {
        final container = makeContainer();
        final controller = await openForm(container);

        controller.setTitle('Read');
        expect(formOf(container).isDirty, isTrue);
        controller.setTitle('');
        expect(formOf(container).isDirty, isFalse);
      },
    );

    test('removing the time also turns the alarm off', () async {
      final container = makeContainer();
      final controller = await openForm(container);

      controller.setReminder(480);
      expect(controller.setAlarm(true), isTrue);
      expect(formOf(container).values.alarmEnabled, isTrue);

      controller.setReminder(null);
      expect(formOf(container).values.reminderMinutes, isNull);
      expect(formOf(container).values.alarmEnabled, isFalse);
    });

    test('an alarm cannot be switched on without a time', () async {
      final container = makeContainer();
      final controller = await openForm(container);

      expect(controller.setAlarm(true), isFalse);
      expect(formOf(container).values.alarmEnabled, isFalse);
      expect(formOf(container).isDirty, isFalse);
    });

    test(
      'toggleDay flips one weekday and the quick picks set the mask',
      () async {
        final container = makeContainer();
        final controller = await openForm(container);

        controller.toggleDay(6); // Sunday off
        expect(formOf(container).values.repeatDays, 63);
        controller.toggleDay(6);
        expect(formOf(container).values.repeatDays, 127);
        controller.setRepeatDays(weekendMask);
        expect(repeatSummary(formOf(container).values.repeatDays), 'Weekends');
      },
    );

    test('nullable fields can be set and cleared', () async {
      final container = makeContainer();
      final controller = await openForm(container);

      controller
        ..setDuration(30)
        ..setSnooze(5);
      expect(formOf(container).values.durationMinutes, 30);
      expect(formOf(container).values.snoozeMinutes, 5);

      controller
        ..setDuration(null)
        ..setSnooze(null);
      expect(formOf(container).values.durationMinutes, isNull);
      expect(formOf(container).values.snoozeMinutes, isNull);
    });
  });

  group('saving a new task', () {
    test('stores the routine and puts it on today\'s checklist', () async {
      final container = makeContainer();
      final controller = await openForm(container);
      controller
        ..setTitle('  Drink water  ')
        ..setDescription('  two glasses ')
        ..setReminder(8 * 60)
        ..setAlarm(true)
        ..setPriority(Priority.high)
        ..setDuration(5)
        ..setCustomMessage('Hydrate!')
        ..setSnooze(15)
        ..setRepeatDays(weekdaysMask);

      final result = await controller.save();

      expect(result, isNot(TaskSaveResult.invalid));
      final stored = await env.routines.watchActive().first;
      expect(stored, hasLength(1));
      final routine = stored.single;
      expect(routine.title, 'Drink water');
      expect(routine.description, 'two glasses');
      expect(routine.reminderMinutes, 480);
      expect(routine.alarmEnabled, isTrue);
      expect(routine.priority, Priority.high);
      expect(routine.durationMinutes, 5);
      expect(routine.customReminderMessage, 'Hydrate!');
      expect(routine.snoozeMinutes, 15);
      expect(routine.repeatDays, weekdaysMask);

      final records = await env.allRecords();
      expect(records, hasLength(1), reason: 'Monday is a weekday');
      expect(records.single.titleSnapshot, 'Drink water');
      expect(records.single.scheduledMinutes, 480);
    });

    test('a saved form is no longer dirty', () async {
      final container = makeContainer();
      final controller = await openForm(container);
      controller.setTitle('Read');

      await controller.save();

      expect(formOf(container).isDirty, isFalse);
      expect(formOf(container).saving, isFalse);
    });

    test('an empty title is refused next to the title field', () async {
      final container = makeContainer();
      final controller = await openForm(container);

      final result = await controller.save();

      expect(result, TaskSaveResult.invalid);
      expect(
        formOf(container).errors[RoutineField.title],
        'Title must be 1-80 characters',
      );
      expect(await env.routines.watchActive().first, isEmpty);

      controller.setTitle('R');
      expect(formOf(container).errors, isEmpty, reason: 'typing clears it');
    });

    test('a title over 80 characters is refused', () async {
      final container = makeContainer();
      final controller = await openForm(container);
      controller.setTitle('x' * 81);

      expect(await controller.save(), TaskSaveResult.invalid);
      expect(formOf(container).errors, contains(RoutineField.title));
    });

    test('no repeat day is refused next to the repeat row', () async {
      final container = makeContainer();
      final controller = await openForm(container);
      controller
        ..setTitle('Read')
        ..setRepeatDays(0);

      expect(await controller.save(), TaskSaveResult.invalid);
      expect(
        formOf(container).errors[RoutineField.repeatDays],
        'Pick at least one repeat day',
      );
      expect(await env.routines.watchActive().first, isEmpty);

      controller.toggleDay(0);
      expect(formOf(container).errors, isEmpty);
    });

    test('saving twice at once creates one routine', () async {
      final container = makeContainer();
      final controller = await openForm(container);
      controller.setTitle('Read');

      final results = await Future.wait([controller.save(), controller.save()]);

      expect(results, contains(TaskSaveResult.invalid));
      expect(await env.routines.watchActive().first, hasLength(1));
    });
  });

  group('saving an edit', () {
    test('updates the routine and keeps its history', () async {
      final id = await env.addRoutine(title: 'Walk', reminderMinutes: 600);
      final container = makeContainer();
      final args = TaskFormArgs(routineId: id);
      final controller = await openForm(container, args);
      controller
        ..setTitle('Long walk')
        ..setReminder(null)
        ..setPriority(Priority.low);

      final result = await controller.save();

      expect(result, TaskSaveResult.saved);
      final routine = (await env.routines.getById(id))!;
      expect(routine.title, 'Long walk');
      expect(routine.reminderMinutes, isNull);
      expect(routine.priority, Priority.low);
      expect(await env.allRecords(), hasLength(1), reason: 'no duplicate');
    });

    test('the routine being gone is reported, not thrown', () async {
      final id = await env.addRoutine();
      final container = makeContainer();
      final args = TaskFormArgs(routineId: id);
      final controller = await openForm(container, args);
      controller.setTitle('Renamed');
      await env.routines.archive(id);

      final result = await controller.save();

      expect(result, TaskSaveResult.invalid);
      expect(formOf(container, args).message, contains('not found'));
      expect(formOf(container, args).saving, isFalse);
    });
  });

  group('asking for notification permission', () {
    Future<TaskSaveResult> saveNew(
      ProviderContainer container, {
      int? reminder,
    }) async {
      final controller = await openForm(container);
      controller
        ..setTitle('Read')
        ..setReminder(reminder);
      return controller.save();
    }

    test('a new reminder while notifications are blocked asks first', () async {
      notifications.notificationsAllowed = false;
      final result = await saveNew(makeContainer(), reminder: 480);

      expect(result, TaskSaveResult.savedNeedsPermission);
      expect(await env.routines.watchActive().first, hasLength(1));
    });

    test('nothing to ask when notifications are on', () async {
      final result = await saveNew(makeContainer(), reminder: 480);
      expect(result, TaskSaveResult.saved);
    });

    test('no reminder, nothing to ask', () async {
      notifications.notificationsAllowed = false;
      final result = await saveNew(makeContainer());
      expect(result, TaskSaveResult.saved);
    });

    test('editing without touching the reminder does not ask again', () async {
      final id = await env.addRoutine(reminderMinutes: 480);
      notifications.notificationsAllowed = false;
      final container = makeContainer();
      final args = TaskFormArgs(routineId: id);
      final controller = await openForm(container, args);
      controller.setTitle('New name');

      expect(await controller.save(), TaskSaveResult.saved);
    });

    test('changing the reminder time asks again', () async {
      final id = await env.addRoutine(reminderMinutes: 480);
      notifications.notificationsAllowed = false;
      final container = makeContainer();
      final args = TaskFormArgs(routineId: id);
      final controller = await openForm(container, args);
      controller.setReminder(9 * 60);

      expect(await controller.save(), TaskSaveResult.savedNeedsPermission);
    });
  });

  group('helpers', () {
    test('the time picker starts at the next full hour', () {
      expect(suggestedReminderMinutes(DateTime(2026, 11, 2, 9, 20)), 10 * 60);
      expect(suggestedReminderMinutes(DateTime(2026, 11, 2, 23, 30)), 0);
    });

    test('repeat days read naturally', () {
      expect(repeatSummary(127), 'Every day');
      expect(repeatSummary(weekdaysMask), 'Weekdays');
      expect(repeatSummary(weekendMask), 'Weekends');
      expect(repeatSummary(0x01 | 0x04 | 0x10), 'Mon, Wed, Fri');
      expect(repeatSummary(0), 'Pick a day');
    });
  });
}

Future<RoutineDraft> _draft(
  TestEnv env, {
  required String title,
  int? reminderMinutes,
  bool alarmEnabled = false,
  int repeatDays = 127,
  Priority priority = Priority.medium,
  int? durationMinutes,
  String? description,
  String? message,
  int? snoozeMinutes,
}) async {
  return RoutineDraft(
    title: title,
    categoryId: await env.generalId(),
    reminderMinutes: reminderMinutes,
    alarmEnabled: alarmEnabled,
    repeatDays: repeatDays,
    priority: priority,
    durationMinutes: durationMinutes,
    description: description,
    customReminderMessage: message,
    snoozeMinutes: snoozeMinutes,
  );
}
