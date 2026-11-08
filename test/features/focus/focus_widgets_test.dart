import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/app.dart';
import 'package:ticky/features/focus/widgets/focus_block_field.dart';
import 'package:ticky/features/focus/widgets/focus_marks.dart';
import 'package:ticky/features/focus/widgets/focus_sheet.dart';

import '../../support/home_test_support.dart';

// homeOverrides runs on Monday 2026-11-02 at 09:00.
const today = '2026-11-02';
const yesterday = '2026-11-01';
const m = focusMarker;

Future<void> pumpHome(WidgetTester tester, List<Override> overrides) async {
  usePhoneScreen(tester);
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const TickyApp()),
  );
  await tester.pumpAndSettle();
}

final sheet = find.byType(FocusSheet);
final sheetFields = find.descendant(
  of: sheet,
  matching: find.byType(TextField),
);
final sheetChecks = find.descendant(
  of: sheet,
  matching: find.byType(FocusCheck),
);

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text("What's the plan today?"));
  await tester.pumpAndSettle();
  expect(sheet, findsOneWidget);
}

Future<void> closeSheet(WidgetTester tester) async {
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

bool hasFocus(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

void main() {
  group('the card on Home', () {
    testWidgets('an empty page is one slim invitation', (tester) async {
      await pumpHome(tester, homeOverrides());

      expect(find.text("TODAY'S FOCUS"), findsOneWidget);
      expect(find.text("What's the plan today?"), findsOneWidget);
      expect(find.byType(FocusRing), findsNothing);
    });

    testWidgets('written goals show progress and can be ticked in place', (
      tester,
    ) async {
      final focus = FakeFocusRepository({today: '- [ ] graphs\n- [ ] trees'});
      await pumpHome(tester, homeOverrides(focus: focus));

      expect(find.text('0 of 2 goals'), findsOneWidget);
      expect(find.text('graphs'), findsOneWidget);

      await tester.tap(find.byType(FocusCheck).first);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 goals'), findsOneWidget);
      expect(focus.notes[today], '- [x] graphs\n- [ ] trees');

      await tester.tap(find.byType(FocusCheck).last);
      await tester.pumpAndSettle();
      expect(find.text('All goals done'), findsOneWidget);
    });

    testWidgets('only the first few lines are previewed', (tester) async {
      final focus = FakeFocusRepository({
        today: '- [ ] a\n- [ ] b\n- [ ] c\n- [ ] d\n- [ ] e',
      });
      await pumpHome(tester, homeOverrides(focus: focus));

      expect(find.text('a'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
      expect(find.text('d'), findsNothing);
      expect(find.text('+ 2 more'), findsOneWidget);
    });

    testWidgets('notes alone read as notes, with no progress ring', (
      tester,
    ) async {
      final focus = FakeFocusRepository({today: '# Spring\nrevise beans'});
      await pumpHome(tester, homeOverrides(focus: focus));

      expect(find.text('Your notes for today'), findsOneWidget);
      expect(find.text('Spring'), findsOneWidget);
      expect(find.byType(FocusRing), findsNothing);
    });

    testWidgets('the checklist is still on Home below the card', (
      tester,
    ) async {
      await pumpHome(
        tester,
        homeOverrides(
          entries: [entry(id: 1, title: 'Drink water', minutes: 480)],
        ),
      );
      expect(find.text('Drink water'), findsOneWidget);
      expect(find.text("What's the plan today?"), findsOneWidget);
    });
  });

  group('writing in the sheet', () {
    testWidgets('typing "[] " makes a goal, Enter makes the next one', (
      tester,
    ) async {
      final focus = FakeFocusRepository();
      await pumpHome(tester, homeOverrides(focus: focus));
      await openSheet(tester);

      expect(sheetFields, findsOneWidget);
      await tester.enterText(sheetFields, '$m[] ');
      await tester.pumpAndSettle();
      expect(sheetChecks, findsOneWidget);

      await tester.enterText(sheetFields, '${m}DSA graphs');
      await tester.pump();
      await tester.enterText(sheetFields, '${m}DSA graphs\n');
      await tester.pumpAndSettle();

      expect(sheetFields, findsNWidgets(2));
      expect(sheetChecks, findsNWidgets(2));
      expect(hasFocus(tester, sheetFields.last), isTrue);

      await tester.enterText(sheetFields.last, '${m}Trees');
      await closeSheet(tester);

      expect(focus.notes[today], '- [ ] DSA graphs\n- [ ] Trees');
    });

    testWidgets('a goal can be ticked in the sheet and the ring follows', (
      tester,
    ) async {
      final focus = FakeFocusRepository({today: '- [ ] a\n- [ ] b'});
      await pumpHome(tester, homeOverrides(focus: focus));
      await tester.tap(find.text('0 of 2 goals'));
      await tester.pumpAndSettle();

      await tester.tap(sheetChecks.first);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: sheet, matching: find.text('1/2')),
        findsOneWidget,
      );
      await closeSheet(tester);
      expect(focus.notes[today], '- [x] a\n- [ ] b');
    });

    testWidgets('the tick and the text of a goal share one centre line, at '
        'any text size', (tester) async {
      final focus = FakeFocusRepository({
        today: '- [ ] graphs\n- [x] trees\n- a bullet\nplain',
      });
      for (final scale in [1.0, 1.6]) {
        await pumpHome(tester, homeOverrides(focus: focus));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        await tester.tap(find.text('1 of 2 goals').first);
        await tester.pumpAndSettle();

        // Row 0 and 1 are goals, row 2 is a bullet.
        for (var i = 0; i < 2; i++) {
          final check = tester.getCenter(sheetChecks.at(i)).dy;
          final field = tester.getCenter(sheetFields.at(i)).dy;
          expect(
            (check - field).abs(),
            lessThan(0.6),
            reason: 'goal $i at text scale $scale',
          );
        }
        await closeSheet(tester);
      }
    });

    testWidgets('a quick start adds a goal and puts the cursor in it', (
      tester,
    ) async {
      final focus = FakeFocusRepository();
      await pumpHome(tester, homeOverrides(focus: focus));
      await openSheet(tester);

      await tester.tap(find.text('Study session'));
      await tester.pumpAndSettle();

      expect(sheetChecks, findsOneWidget);
      expect(hasFocus(tester, sheetFields.first), isTrue);
      await closeSheet(tester);
      expect(focus.notes[today], '- [ ] Study session');
    });

    testWidgets('Backspace at the start of a goal makes it plain text, then '
        'joins it to the line above', (tester) async {
      final focus = FakeFocusRepository({today: '- [ ] a\n- [ ] b'});
      await pumpHome(tester, homeOverrides(focus: focus));
      await tester.tap(find.text('0 of 2 goals'));
      await tester.pumpAndSettle();

      // Deleting the marker is what Backspace at the start looks like.
      await tester.enterText(sheetFields.last, 'b');
      await tester.pumpAndSettle();
      expect(sheetChecks, findsOneWidget);

      await tester.enterText(sheetFields.last, 'b');
      await tester.pumpAndSettle();
      expect(sheetFields, findsOneWidget);

      await closeSheet(tester);
      expect(focus.notes[today], '- [ ] ab');
    });

    testWidgets('Enter on an empty goal leaves the list', (tester) async {
      final focus = FakeFocusRepository({today: '- [ ] a\n- [ ] '});
      await pumpHome(tester, homeOverrides(focus: focus));
      await tester.tap(find.text('0 of 1 goal'));
      await tester.pumpAndSettle();
      expect(sheetChecks, findsNWidgets(2));

      await tester.enterText(sheetFields.last, '$m\n');
      await tester.pumpAndSettle();

      expect(sheetFields, findsNWidgets(2));
      expect(sheetChecks, findsOneWidget);
    });

    testWidgets('the toolbar changes the type of the current line', (
      tester,
    ) async {
      final focus = FakeFocusRepository({today: 'plain note'});
      await pumpHome(tester, homeOverrides(focus: focus));
      await tester.tap(find.text('Your notes for today'));
      await tester.pumpAndSettle();

      await tester.tap(sheetFields.first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Goal'));
      await tester.pumpAndSettle();
      expect(sheetChecks, findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Goal'));
      await tester.pumpAndSettle();
      expect(sheetChecks, findsNothing);

      await tester.tap(find.bySemanticsLabel('Heading'));
      await closeSheet(tester);
      expect(focus.notes[today], '# plain note');
    });

    testWidgets('the delete button removes the current line', (tester) async {
      final focus = FakeFocusRepository({today: 'one\ntwo'});
      await pumpHome(tester, homeOverrides(focus: focus));
      await tester.tap(find.text('Your notes for today'));
      await tester.pumpAndSettle();

      await tester.tap(sheetFields.last);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Delete line'));
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(focus.notes[today], 'one');
    });

    testWidgets('a pasted markdown list becomes goals', (tester) async {
      final focus = FakeFocusRepository();
      await pumpHome(tester, homeOverrides(focus: focus));
      await openSheet(tester);

      await tester.enterText(
        sheetFields,
        '$m- [ ] graphs\n- [x] trees\n- [ ] spring',
      );
      await tester.pumpAndSettle();

      expect(sheetChecks, findsNWidgets(3));
      await closeSheet(tester);
      expect(focus.notes[today], '- [ ] graphs\n- [x] trees\n- [ ] spring');
    });

    testWidgets('clearing the page leaves nothing saved', (tester) async {
      final focus = FakeFocusRepository({today: 'a note'});
      await pumpHome(tester, homeOverrides(focus: focus));
      await tester.tap(find.text('Your notes for today'));
      await tester.pumpAndSettle();

      await tester.enterText(sheetFields, m);
      await closeSheet(tester);

      expect(focus.notes, isEmpty);
      expect(find.text("What's the plan today?"), findsOneWidget);
    });

    testWidgets('closing the sheet saves what was typed', (tester) async {
      final focus = FakeFocusRepository();
      await pumpHome(tester, homeOverrides(focus: focus));
      await openSheet(tester);

      await tester.enterText(sheetFields, '${m}revise Spring');
      await closeSheet(tester);

      expect(focus.notes[today], 'revise Spring');
      expect(find.text('Your notes for today'), findsOneWidget);
    });
  });

  group("bring yesterday's page over", () {
    FakeFocusRepository withYesterday() => FakeFocusRepository({
      yesterday: '- [x] graphs\n- [ ] trees\n- [ ] spring',
    });

    testWidgets('the card asks, with the numbers', (tester) async {
      await pumpHome(tester, homeOverrides(focus: withYesterday()));

      expect(find.text("Bring yesterday's focus over?"), findsOneWidget);
      expect(find.text('3 goals · 2 unfinished'), findsOneWidget);
      expect(find.text('Bring 2 unfinished'), findsOneWidget);
      expect(find.text('Copy all'), findsOneWidget);
      expect(find.text('Start fresh'), findsOneWidget);
    });

    testWidgets('"Bring unfinished" copies only what was left', (tester) async {
      final focus = withYesterday();
      await pumpHome(tester, homeOverrides(focus: focus));

      await tester.tap(find.text('Bring 2 unfinished'));
      await tester.pumpAndSettle();

      expect(find.text('0 of 2 goals'), findsOneWidget);
      expect(find.text('graphs'), findsNothing);
      expect(find.text("Bring yesterday's focus over?"), findsNothing);
      expect(focus.notes[today], '- [ ] trees\n- [ ] spring');
      expect(focus.notes[yesterday], '- [x] graphs\n- [ ] trees\n- [ ] spring');
    });

    testWidgets('"Copy all" brings everything, unticked', (tester) async {
      final focus = withYesterday();
      await pumpHome(tester, homeOverrides(focus: focus));

      await tester.tap(find.text('Copy all'));
      await tester.pumpAndSettle();

      expect(find.text('0 of 3 goals'), findsOneWidget);
      expect(focus.notes[today], '- [ ] graphs\n- [ ] trees\n- [ ] spring');
    });

    testWidgets('"Start fresh" leaves a clean page and does not ask again', (
      tester,
    ) async {
      final focus = withYesterday();
      final settings = FakeSettings();
      await pumpHome(tester, homeOverrides(focus: focus, settings: settings));

      await tester.tap(find.text('Start fresh'));
      await tester.pumpAndSettle();

      expect(find.text("What's the plan today?"), findsOneWidget);
      expect(find.text("Bring yesterday's focus over?"), findsNothing);
      expect(focus.notes.containsKey(today), isFalse);
      expect(settings.focusCarryAnswered, today);
    });

    testWidgets('an answered question stays answered', (tester) async {
      final settings = FakeSettings()..focusCarryAnswered = today;
      await pumpHome(
        tester,
        homeOverrides(focus: withYesterday(), settings: settings),
      );
      expect(find.text("Bring yesterday's focus over?"), findsNothing);
      expect(find.text("What's the plan today?"), findsOneWidget);
    });

    testWidgets('the sheet asks too, and does not pop the keyboard first', (
      tester,
    ) async {
      await pumpHome(tester, homeOverrides(focus: withYesterday()));

      await tester.tap(find.text('3 goals · 2 unfinished'));
      await tester.pumpAndSettle();

      expect(sheet, findsOneWidget);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text("Bring yesterday's focus over?"),
        ),
        findsOneWidget,
      );
      expect(hasFocus(tester, sheetFields.first), isFalse);
    });

    testWidgets('a note from a few days ago is named by its weekday', (
      tester,
    ) async {
      // 2026-10-30 is a Friday.
      final focus = FakeFocusRepository({'2026-10-30': '- [ ] trees'});
      await pumpHome(tester, homeOverrides(focus: focus));
      expect(find.text("Bring Friday's focus over?"), findsOneWidget);
    });
  });
}
