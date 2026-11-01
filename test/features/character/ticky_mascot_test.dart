import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/features/character/models/mascot_assets.dart';
import 'package:ticky/features/character/models/mascot_mood.dart';
import 'package:ticky/features/character/widgets/ticky_mascot.dart';

import '../../support/home_test_support.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('every mood maps to a declared asset', () {
    final paths = {for (final m in MascotMood.values) MascotAssets.pathFor(m)};

    expect(paths, isNotEmpty);
    for (final path in paths) {
      expect(path, startsWith('assets/ticky_asset_pack/character/'));
      expect(path, endsWith('.png'));
    }
  });

  testWidgets('every mood image actually loads from the bundle', (
    tester,
  ) async {
    usePhoneScreen(tester);
    for (final mood in MascotMood.values) {
      await tester.pumpWidget(host(TickyMascot(mood: mood)));
      await tester.pump();

      expect(
        find.byIcon(Icons.access_time_filled_rounded),
        findsNothing,
        reason: '$mood fell back to the error icon',
      );
    }
  });

  /// Vertical scale of Ticky's squash-and-stretch right now (1 = at rest).
  double squashY(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(TickyMascot),
            matching: find.byType(Transform),
          )
          .last,
    );
    return transform.transform.getRow(1)[1];
  }

  testWidgets('is perfectly still at rest: no ambient animation', (
    tester,
  ) async {
    usePhoneScreen(tester, reduceMotion: false);
    await tester.pumpWidget(host(const TickyMascot(mood: MascotMood.idle)));
    await tester.pumpAndSettle(); // lets the one-time entrance finish

    expect(tester.hasRunningAnimations, isFalse);
    final before = tester.getTopLeft(find.byType(Image));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(find.byType(Image)), before);
    expect(squashY(tester), 1);
  });

  testWidgets('a tap squashes him, then he springs back to rest', (
    tester,
  ) async {
    usePhoneScreen(tester, reduceMotion: false);
    await tester.pumpWidget(
      host(TickyMascot(mood: MascotMood.happy, onTap: () {})),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TickyMascot));
    await tester.pump(const Duration(milliseconds: 16));
    expect(squashY(tester), lessThan(0.97), reason: 'squashed on impact');

    await tester.pumpAndSettle();
    expect(squashY(tester), closeTo(1, 0.001), reason: 'settled');
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a mood change gives a gentler squash', (tester) async {
    usePhoneScreen(tester, reduceMotion: false);
    final mood = ValueNotifier(MascotMood.idle);
    await tester.pumpWidget(
      host(
        ValueListenableBuilder(
          valueListenable: mood,
          builder: (_, m, _) => TickyMascot(mood: m),
        ),
      ),
    );
    await tester.pumpAndSettle();

    mood.value = MascotMood.celebrating;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final y = squashY(tester);
    expect(y, lessThan(1));
    expect(y, greaterThan(0.95));
    await tester.pumpAndSettle();
    expect(squashY(tester), closeTo(1, 0.001));
  });

  testWidgets('reduce motion: no entrance and no squash', (tester) async {
    usePhoneScreen(tester, reduceMotion: true);
    await tester.pumpWidget(
      host(TickyMascot(mood: MascotMood.happy, onTap: () {})),
    );

    expect(tester.hasRunningAnimations, isFalse);
    await tester.tap(find.byType(TickyMascot));
    await tester.pump(const Duration(milliseconds: 16));

    expect(squashY(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('tapping calls back', (tester) async {
    usePhoneScreen(tester);
    var taps = 0;
    await tester.pumpWidget(
      host(TickyMascot(mood: MascotMood.happy, onTap: () => taps++)),
    );

    await tester.tap(find.byType(TickyMascot));

    expect(taps, 1);
  });
}
