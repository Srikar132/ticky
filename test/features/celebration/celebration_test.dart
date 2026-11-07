import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/theme/app_theme.dart';
import 'package:ticky/features/celebration/data/celebration_quotes.dart';
import 'package:ticky/features/celebration/widgets/all_done_sheet.dart';
import 'package:ticky/features/celebration/widgets/confetti.dart';
import 'package:ticky/features/home/widgets/task_tile.dart';

Widget app(Widget home, {bool reduceMotion = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(body: home),
  );
}

void main() {
  group('quotes', () {
    test('there is a collection, each with text and an author', () {
      expect(celebrationQuotes.length, greaterThanOrEqualTo(10));
      for (final quote in celebrationQuotes) {
        expect(quote.text.trim(), isNotEmpty);
        expect(quote.author.trim(), isNotEmpty);
      }
    });

    test('no line is repeated', () {
      final texts = celebrationQuotes.map((q) => q.text).toSet();
      expect(texts, hasLength(celebrationQuotes.length));
    });

    test('a random pick comes from the collection and can be repeated', () {
      expect(celebrationQuotes, contains(randomCelebrationQuote()));
      expect(
        randomCelebrationQuote(Random(7)),
        same(randomCelebrationQuote(Random(7))),
      );
    });

    test('every line can come up', () {
      final rng = Random(1);
      final seen = {for (var i = 0; i < 600; i++) randomCelebrationQuote(rng)};
      expect(seen, hasLength(celebrationQuotes.length));
    });
  });

  group('confetti', () {
    testWidgets('plays over the page, then removes itself', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      expect(find.byType(ConfettiBurst), findsNothing);

      playConfetti(context, origin: const Offset(100, 100));
      await tester.pump();
      expect(find.byType(ConfettiBurst), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ConfettiBurst), findsOneWidget, reason: 'mid-flight');

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.byType(ConfettiBurst), findsNothing);
    });

    testWidgets('the party lasts longer than a pop', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox.expand();
            },
          ),
        ),
      );

      playConfetti(context, style: ConfettiStyle.party);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(ConfettiBurst), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.byType(ConfettiBurst), findsNothing);
    });

    testWidgets('does not block taps and is hidden from screen readers', (
      tester,
    ) async {
      var taps = 0;
      late BuildContext context;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (c) {
              context = c;
              return Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('Tap me'),
                ),
              );
            },
          ),
        ),
      );

      playConfetti(context, style: ConfettiStyle.party);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Tap me'));
      expect(taps, 1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });

    testWidgets('stays still when the system reduces motion', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox.expand();
            },
          ),
          reduceMotion: true,
        ),
      );

      playConfetti(context);
      playConfetti(context, style: ConfettiStyle.party);
      await tester.pump();

      expect(find.byType(ConfettiBurst), findsNothing);
    });
  });

  group('the check circle', () {
    Future<void Function(TaskStatus)> pumpCheck(
      WidgetTester tester,
      TaskStatus start, {
      bool reduceMotion = false,
    }) async {
      late StateSetter set;
      var status = start;
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Center(
                child: TaskCheck(status: status, onTap: () {}),
              );
            },
          ),
          reduceMotion: reduceMotion,
        ),
      );
      return (next) {
        set(() => status = next);
      };
    }

    testWidgets('pops confetti when a task becomes completed', (tester) async {
      final change = await pumpCheck(tester, TaskStatus.pending);
      expect(find.byType(ConfettiBurst), findsNothing);

      change(TaskStatus.completed);
      await tester.pump();
      await tester.pump();
      expect(find.byType(ConfettiBurst), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.byType(ConfettiBurst), findsNothing);
    });

    testWidgets('does not pop for a task that was already done', (
      tester,
    ) async {
      await pumpCheck(tester, TaskStatus.completed);
      await tester.pump();
      expect(find.byType(ConfettiBurst), findsNothing);
    });

    testWidgets('does not pop when undoing or skipping', (tester) async {
      final change = await pumpCheck(tester, TaskStatus.completed);
      change(TaskStatus.pending);
      await tester.pump();
      await tester.pump();
      change(TaskStatus.skipped);
      await tester.pump();
      await tester.pump();

      expect(find.byType(ConfettiBurst), findsNothing);
    });

    testWidgets('pops again when re-completed', (tester) async {
      final change = await pumpCheck(tester, TaskStatus.pending);
      change(TaskStatus.completed);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      change(TaskStatus.pending);
      await tester.pump();
      change(TaskStatus.completed);
      await tester.pump();
      await tester.pump();

      expect(find.byType(ConfettiBurst), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    });

    testWidgets('stays still when the system reduces motion', (tester) async {
      final change = await pumpCheck(
        tester,
        TaskStatus.pending,
        reduceMotion: true,
      );
      change(TaskStatus.completed);
      await tester.pump();
      await tester.pump();

      expect(find.byType(ConfettiBurst), findsNothing);
    });
  });

  group('all done sheet', () {
    const quote = CelebrationQuote('Tick, tock. Look at you go!', 'Ticky');

    Future<void> open(
      WidgetTester tester, {
      int coins = 7,
      CelebrationQuote? line,
    }) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () =>
                    showAllDoneSheet(context, coinsEarned: coins, quote: line),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('congratulates, shows the coins and the quote', (tester) async {
      await open(tester, line: quote);

      expect(find.text('Congratulations!'), findsOneWidget);
      expect(find.textContaining('finished everything'), findsOneWidget);
      expect(find.text('+7 coins today'), findsOneWidget);
      expect(find.text('“Tick, tock. Look at you go!”'), findsOneWidget);
      expect(find.text('Ticky'), findsOneWidget);
    });

    testWidgets('OK closes it', (tester) async {
      await open(tester, line: quote);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Congratulations!'), findsNothing);
    });

    testWidgets('picks a random line from the collection by default', (
      tester,
    ) async {
      await open(tester);

      final shown = celebrationQuotes.where(
        (q) => find.text('“${q.text}”').evaluate().isNotEmpty,
      );
      expect(shown, hasLength(1));
    });

    testWidgets('leaves out the coin pill when nothing was earned', (
      tester,
    ) async {
      await open(tester, coins: 0, line: quote);

      expect(find.textContaining('coins today'), findsNothing);
      expect(find.text('Congratulations!'), findsOneWidget);
    });
  });
}
