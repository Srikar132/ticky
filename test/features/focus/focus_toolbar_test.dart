import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/app.dart';
import 'package:ticky/features/focus/widgets/focus_marks.dart';
import 'package:ticky/features/focus/widgets/focus_sheet.dart';

import '../../support/home_test_support.dart';

// homeOverrides runs on Monday 2026-11-02 at 09:00.
const today = '2026-11-02';

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

Future<void> openSheetOn(WidgetTester tester, String cardText) async {
  await tester.tap(find.text(cardText));
  await tester.pumpAndSettle();
  expect(sheet, findsOneWidget);
}

Future<void> closeSheet(WidgetTester tester) async {
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

Future<void> tapTool(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Undo brings back a deleted line', (tester) async {
    final focus = FakeFocusRepository({today: 'one\ntwo\nthree'});
    await pumpHome(tester, homeOverrides(focus: focus));
    await openSheetOn(tester, 'Your notes for today');

    await tester.tap(sheetFields.at(1));
    await tester.pumpAndSettle();
    await tapTool(tester, 'Delete line');
    expect(sheetFields, findsNWidgets(2));

    await tapTool(tester, 'Undo');
    expect(sheetFields, findsNWidgets(3));

    await closeSheet(tester);
    expect(focus.notes[today], 'one\ntwo\nthree');
  });

  testWidgets('Undo is disabled until there is something to undo', (
    tester,
  ) async {
    final focus = FakeFocusRepository({today: 'one'});
    await pumpHome(tester, homeOverrides(focus: focus));
    await openSheetOn(tester, 'Your notes for today');

    final undo = find.bySemanticsLabel('Undo');
    expect(
      tester.getSemantics(undo),
      matchesSemantics(
        label: 'Undo',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasSelectedState: true,
      ),
    );
  });

  testWidgets('move down and up reorder the current line', (tester) async {
    final focus = FakeFocusRepository({today: 'one\ntwo\nthree'});
    await pumpHome(tester, homeOverrides(focus: focus));
    await openSheetOn(tester, 'Your notes for today');

    await tester.tap(sheetFields.first);
    await tester.pumpAndSettle();
    await tapTool(tester, 'Move line down');
    await tapTool(tester, 'Move line down');
    await closeSheet(tester);
    expect(focus.notes[today], 'two\nthree\none');

    await openSheetOn(tester, 'Your notes for today');
    await tester.tap(sheetFields.last);
    await tester.pumpAndSettle();
    await tapTool(tester, 'Move line up');
    await closeSheet(tester);
    expect(focus.notes[today], 'two\none\nthree');
  });

  testWidgets('the menu clears done goals, and Undo restores them', (
    tester,
  ) async {
    final focus = FakeFocusRepository({today: '- [x] a\n- [ ] b\n- [x] c'});
    await pumpHome(tester, homeOverrides(focus: focus));
    await openSheetOn(tester, '2 of 3 goals');

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear done goals'));
    await tester.pumpAndSettle();
    expect(sheetChecks, findsOneWidget);

    await tapTool(tester, 'Undo');
    expect(sheetChecks, findsNWidgets(3));

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear done goals'));
    await tester.pumpAndSettle();
    await closeSheet(tester);
    expect(focus.notes[today], '- [ ] b');
  });

  testWidgets('"Clear done goals" is off when nothing is ticked', (
    tester,
  ) async {
    final focus = FakeFocusRepository({today: '- [ ] a'});
    await pumpHome(tester, homeOverrides(focus: focus));
    await openSheetOn(tester, '0 of 1 goal');

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    final item = tester.widget<PopupMenuItem<Object?>>(
      find.ancestor(
        of: find.text('Clear done goals'),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      ),
    );
    expect(item.enabled, isFalse);
  });

  testWidgets('the menu copies the page as markdown', (tester) async {
    final focus = FakeFocusRepository({today: '# Plan\n- [x] a\n- [ ] b'});
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpHome(tester, homeOverrides(focus: focus));
    await openSheetOn(tester, '1 of 2 goals');

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy as text'));
    await tester.pump();
    await tester.pump();

    expect(copied, '# Plan\n- [x] a\n- [ ] b');
    expect(find.text('Copied to clipboard'), findsOneWidget);

    // The note fades back to the date by itself.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copied to clipboard'), findsNothing);
  });
}
