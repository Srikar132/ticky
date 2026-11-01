import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/default_categories.dart';
import 'package:ticky/features/categories/models/category_draft.dart';
import 'package:ticky/features/categories/models/category_options.dart';
import 'package:ticky/features/tasks/models/routine_draft.dart';

import '../../support/test_env.dart';

CategoryDraft draft({
  String title = 'Fitness',
  String iconKey = 'fitness_center',
  int colorValue = 0xFF4DB6AC,
}) => CategoryDraft(title: title, iconKey: iconKey, colorValue: colorValue);

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  Future<int> routineIn(int categoryId, {String title = 'Task'}) {
    return env.routines.create(
      RoutineDraft(title: title, categoryId: categoryId),
    );
  }

  group('options', () {
    test('every seeded default category uses an icon from the map', () {
      for (final category in defaultCategories) {
        expect(categoryIcons, contains(category.iconKey), reason: category.key);
      }
    });

    test('unknown icon keys fall back instead of crashing', () {
      expect(iconForCategoryKey('does_not_exist'), fallbackCategoryIcon);
      expect(iconForCategoryKey('work'), categoryIcons['work']);
    });

    test('colour choices are opaque and unique', () {
      expect(categoryColors.toSet(), hasLength(categoryColors.length));
      expect(categoryColors.every((c) => (c >> 24) & 0xFF == 0xFF), isTrue);
    });
  });

  group('reading', () {
    test('lists the seeded defaults in order, General first', () async {
      final active = await env.categories.getActive();

      expect(active.map((c) => c.key), defaultCategories.map((c) => c.key));
      expect(active.first.key, generalCategoryKey);
      expect(await env.categories.getGeneralId(), active.first.id);
    });

    test('getById also finds archived categories', () async {
      final id = await env.categories.create(draft());
      await env.categories.archive(id);

      expect((await env.categories.getById(id))!.archivedAt, isNotNull);
      expect(await env.categories.getById(9999), isNull);
    });
  });

  group('create', () {
    test('adds a custom category at the end', () async {
      final id = await env.categories.create(draft(title: '  Gym  '));

      final created = (await env.categories.getById(id))!;
      expect(created.title, 'Gym');
      expect(created.key, isNull);
      expect(created.isDefault, isFalse);
      expect(created.archivedAt, isNull);
      expect(created.sortOrder, defaultCategories.length);
      final active = await env.categories.getActive();
      expect(active.last.id, id);
    });

    test('rejects bad drafts', () {
      final bad = <CategoryDraft>[
        draft(title: '   '),
        draft(title: 'x' * 41),
        draft(iconKey: 'not_an_icon'),
        draft(colorValue: 0x808B5CF6), // translucent
      ];

      for (final item in bad) {
        expect(
          env.categories.create(item),
          throwsA(isA<InvalidCategoryException>()),
          reason: '${item.title} ${item.iconKey}',
        );
      }
    });

    test('a new category can be used by a routine', () async {
      final id = await env.categories.create(draft());

      final routineId = await routineIn(id);

      expect((await env.routines.getById(routineId))!.categoryId, id);
    });
  });

  group('update', () {
    test('changes title, icon and colour', () async {
      final id = await env.categories.create(draft());

      await env.categories.update(
        id,
        draft(
          title: 'Workout',
          iconKey: 'directions_run',
          colorValue: 0xFFE57373,
        ),
      );

      final updated = (await env.categories.getById(id))!;
      expect(updated.title, 'Workout');
      expect(updated.iconKey, 'directions_run');
      expect(updated.colorValue, 0xFFE57373);
    });

    test('a renamed default keeps its stable key', () async {
      final generalId = await env.categories.getGeneralId();

      await env.categories.update(generalId, draft(title: 'Everything'));

      final general = (await env.categories.getById(generalId))!;
      expect(general.key, generalCategoryKey);
      expect(general.isDefault, isTrue);
      expect(await env.categories.getGeneralId(), generalId);
    });

    test('rejects bad drafts, missing and archived categories', () async {
      final id = await env.categories.create(draft());

      await expectLater(
        env.categories.update(id, draft(title: '')),
        throwsA(isA<InvalidCategoryException>()),
      );
      await expectLater(
        env.categories.update(9999, draft()),
        throwsA(isA<NotFoundException>()),
      );
      await env.categories.archive(id);
      await expectLater(
        env.categories.update(id, draft()),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('archive', () {
    test('General can never be archived', () async {
      final generalId = await env.categories.getGeneralId();

      await expectLater(
        env.categories.archive(generalId),
        throwsA(isA<InvalidCategoryException>()),
      );

      expect((await env.categories.getById(generalId))!.archivedAt, isNull);
    });

    test('hides the category from pickers but keeps the row', () async {
      final id = await env.categories.create(draft());

      await env.categories.archive(id);

      expect(
        (await env.categories.getActive()).map((c) => c.id),
        isNot(contains(id)),
      );
      expect(
        (await env.categories.watchAll().first).map((c) => c.id),
        contains(id),
      );
      expect(
        (await env.categories.watchActive().first).map((c) => c.id),
        isNot(contains(id)),
      );
    });

    test('moves active routines (including paused) to General', () async {
      final generalId = await env.categories.getGeneralId();
      final id = await env.categories.create(draft());
      final running = await routineIn(id, title: 'Running');
      final paused = await routineIn(id, title: 'Paused');
      await env.routines.setEnabled(paused, false);
      final other = await routineIn(generalId, title: 'Other');

      await env.categories.archive(id);

      expect((await env.routines.getById(running))!.categoryId, generalId);
      expect((await env.routines.getById(paused))!.categoryId, generalId);
      expect((await env.routines.getById(other))!.categoryId, generalId);
    });

    test(
      'leaves archived routines pointing at the archived category',
      () async {
        final id = await env.categories.create(draft());
        final old = await routineIn(id, title: 'Old');
        await env.routines.archive(old);

        await env.categories.archive(id);

        expect((await env.routines.getById(old))!.categoryId, id);
      },
    );

    test('does not move routines of other categories', () async {
      final gym = await env.categories.create(draft(title: 'Gym'));
      final reading = await env.categories.create(
        draft(title: 'Reading', iconKey: 'menu_book'),
      );
      final readingTask = await routineIn(reading);

      await env.categories.archive(gym);

      expect((await env.routines.getById(readingTask))!.categoryId, reading);
    });

    test(
      'history is untouched: records keep their routine and snapshot',
      () async {
        final id = await env.categories.create(draft());
        final routineId = await routineIn(id, title: 'Running');
        await env.reconciler.reconcile(env.now);
        final before = await env.recordFor(routineId, '2026-11-02');

        await env.categories.archive(id);

        final after = await env.recordFor(routineId, '2026-11-02');
        expect(after.id, before.id);
        expect(after.titleSnapshot, 'Running');
        expect(after.status, before.status);
      },
    );

    test('an archived category cannot be picked for a new routine', () async {
      final id = await env.categories.create(draft());
      await env.categories.archive(id);

      await expectLater(routineIn(id), throwsA(isA<InvalidRoutineException>()));
    });

    test('archiving twice or a missing id fails', () async {
      final id = await env.categories.create(draft());
      await env.categories.archive(id);

      await expectLater(
        env.categories.archive(id),
        throwsA(isA<NotFoundException>()),
      );
      await expectLater(
        env.categories.archive(9999),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
