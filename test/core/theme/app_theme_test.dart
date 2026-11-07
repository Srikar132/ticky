import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/theme/app_colors.dart';
import 'package:ticky/core/theme/app_text_theme.dart';
import 'package:ticky/core/theme/app_theme.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/color_tones.dart';
import 'package:ticky/core/theme/ticky_colors.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final themes = {'light': AppTheme.light, 'dark': AppTheme.dark};

  test('there is a light and a dark Material 3 theme', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    for (final theme in themes.values) {
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    }
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.canvas);
    expect(AppTheme.dark.scaffoldBackgroundColor, AppDarkColors.canvas);
  });

  for (final MapEntry(key: name, value: theme) in themes.entries) {
    group('$name theme', () {
      final scheme = theme.colorScheme;
      final colors = theme.extension<TickyColors>()!;

      test('text and key colour pairs are readable (WCAG AA)', () {
        final pairs = <String, (Color, Color, double)>{
          'text on page': (scheme.onSurface, scheme.surface, 7),
          'text on card': (scheme.onSurface, scheme.surfaceContainer, 7),
          'muted text on page': (scheme.onSurfaceVariant, scheme.surface, 4.5),
          'muted text on card': (
            scheme.onSurfaceVariant,
            scheme.surfaceContainer,
            4.5,
          ),
          'muted text on fill': (
            scheme.onSurfaceVariant,
            scheme.surfaceContainerHigh,
            4.5,
          ),
          'label on primary': (scheme.onPrimary, scheme.primary, 4.5),
          'label on ink': (scheme.onInverseSurface, scheme.inverseSurface, 7),
          'on primary container': (
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
            4.5,
          ),
          'error on page': (scheme.error, scheme.surface, 4.5),
          'success on card': (colors.success, scheme.surfaceContainer, 3),
          'warning on card': (colors.warning, scheme.surfaceContainer, 3.5),
          'text on lavender tile': (scheme.onSurface, colors.tileLavender, 7),
          'text on blue tile': (scheme.onSurface, colors.tileBlue, 7),
          'text on pink tile': (scheme.onSurface, colors.tilePink, 7),
          'text on mint tile': (scheme.onSurface, colors.tileMint, 7),
          'text on butter tile': (scheme.onSurface, colors.tileButter, 7),
          'text on peach tile': (scheme.onSurface, colors.tilePeach, 7),
        };

        for (final entry in pairs.entries) {
          final (foreground, background, minimum) = entry.value;
          expect(
            contrast(foreground, background),
            greaterThanOrEqualTo(minimum),
            reason: entry.key,
          );
        }
      });

      test('primary buttons are solid ink pills with no shadow', () {
        final style = theme.filledButtonTheme.style!;
        final background = style.backgroundColor!.resolve({})!;
        final foreground = style.foregroundColor!.resolve({})!;

        expect(background, scheme.inverseSurface);
        expect(foreground, scheme.onInverseSurface);
        expect(style.shape!.resolve({}), isA<StadiumBorder>());
        expect(style.elevation!.resolve({}), 0);
        expect(
          style.minimumSize!.resolve({}),
          const Size.fromHeight(AppSizes.control),
        );
      });

      test(
        'cards, sheets and dialogs are soft and rounded, with no outline',
        () {
          final card = theme.cardTheme.shape! as RoundedRectangleBorder;
          final sheet = theme.bottomSheetTheme.shape! as RoundedRectangleBorder;
          final dialog = theme.dialogTheme.shape! as RoundedRectangleBorder;

          expect(theme.cardTheme.elevation, 0);
          expect(theme.cardTheme.color, scheme.surfaceContainerLow);
          expect(card.borderRadius, AppRadius.lgAll);
          expect(card.side, BorderSide.none);
          expect(
            sheet.borderRadius,
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          );
          expect(dialog.borderRadius, AppRadius.xlAll);
        },
      );

      test('chips select to ink, switches use purple only when on', () {
        expect(theme.chipTheme.selectedColor, scheme.inverseSurface);
        expect(theme.chipTheme.shape, isA<StadiumBorder>());

        final track = theme.switchTheme.trackColor!;
        expect(track.resolve({WidgetState.selected}), scheme.primary);
        expect(track.resolve({}), isNot(scheme.primary));
      });

      test('inputs are softly rounded and turn purple when focused', () {
        final input = theme.inputDecorationTheme;
        final focused = input.focusedBorder! as OutlineInputBorder;
        expect(focused.borderSide.color, scheme.primary);
        expect(focused.borderSide.width, AppStroke.focus);
      });

      test('snackbars and tooltips are ink', () {
        expect(theme.snackBarTheme.backgroundColor, scheme.inverseSurface);
        final tooltip = theme.tooltipTheme.decoration! as BoxDecoration;
        expect(tooltip.color, scheme.inverseSurface);
      });

      test('exposes status and tile colours through the extension', () {
        expect(colors.copyWith(coin: Colors.red).coin, Colors.red);
        expect(colors.lerp(colors, 0.5).streak, colors.streak);
        expect(colors.lerp(null, 0.5), same(colors));
      });
    });
  }

  test('the app bar is transparent, with icons that suit each theme', () {
    expect(AppTheme.light.appBarTheme.backgroundColor, Colors.transparent);
    expect(
      AppTheme.light.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
      Brightness.dark,
    );
    expect(
      AppTheme.dark.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
      Brightness.light,
    );
  });

  test('radii are round and grow with the size of the surface', () {
    expect(AppRadius.sm, lessThan(AppRadius.md));
    expect(AppRadius.md, lessThan(AppRadius.lg));
    expect(AppRadius.lg, lessThan(AppRadius.xl));
    expect(AppRadius.lg, 24);
  });

  group('category tones', () {
    const red = Color(0xFFE57373);

    test('light: a pale wash with a dark readable label', () {
      final soft = red.soft(Brightness.light);
      final deep = red.deep(Brightness.light);
      expect(soft.computeLuminance(), greaterThan(0.6));
      expect(contrast(deep, soft), greaterThanOrEqualTo(4.5));
    });

    test('dark: a deep wash with a light readable label', () {
      final soft = red.soft(Brightness.dark);
      final deep = red.deep(Brightness.dark);
      expect(soft.computeLuminance(), lessThan(0.2));
      expect(contrast(deep, soft), greaterThanOrEqualTo(4.5));
    });
  });

  group('typography', () {
    final text = AppTheme.light.textTheme;

    test('headlines are big and bold with tight tracking', () {
      expect(text.headlineLarge!.fontSize, 36);
      for (final style in [text.headlineLarge!, text.headlineMedium!]) {
        expect(style.fontWeight, FontWeight.w700);
        expect(style.letterSpacing, lessThan(0));
      }
      expect(text.titleMedium!.fontWeight, FontWeight.w600);
    });

    test('body text is relaxed', () {
      expect(text.bodyLarge!.fontSize, 16);
      expect(text.bodyMedium!.height, greaterThanOrEqualTo(1.35));
    });

    test('secondary text is muted', () {
      expect(
        text.bodySmall!.color,
        AppTheme.light.colorScheme.onSurfaceVariant,
      );
      expect(
        AppTheme.dark.textTheme.bodySmall!.color,
        AppTheme.dark.colorScheme.onSurfaceVariant,
      );
    });

    test('every style uses the bundled Outfit font', () {
      expect(tickyFontFamily, 'Outfit');
      for (final style in [
        text.displayLarge,
        text.headlineLarge,
        text.titleMedium,
        text.bodyLarge,
        text.bodySmall,
        text.labelLarge,
        text.labelSmall,
      ]) {
        expect(style!.fontFamily, 'Outfit');
      }
    });

    test('the font files and licence are declared in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final file in [
        'Outfit-Regular.ttf',
        'Outfit-Medium.ttf',
        'Outfit-SemiBold.ttf',
        'Outfit-Bold.ttf',
        'OFL.txt',
      ]) {
        expect(pubspec, contains('assets/fonts/outfit/$file'));
        expect(File('assets/fonts/outfit/$file').existsSync(), isTrue);
      }
    });
  });
}
