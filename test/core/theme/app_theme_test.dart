import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/theme/app_colors.dart';
import 'package:ticky/core/theme/app_text_theme.dart';
import 'package:ticky/core/theme/app_theme.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final theme = AppTheme.dark;
  final scheme = theme.colorScheme;

  test('is a dark Material 3 theme built from the brand palette', () {
    expect(theme.brightness, Brightness.dark);
    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0B0912));
    expect(scheme.primary, const Color(0xFF8B5CF6));
    expect(scheme.secondary, const Color(0xFFA78BFA));
    expect(scheme.tertiary, const Color(0xFFC4B5FD));
    expect(scheme.onSurface, const Color(0xFFF5F3FF));
  });

  test('matches the native splash and launcher background', () {
    // Hex also appears in pubspec.yaml (splash, adaptive icon); keep in sync.
    expect(AppColors.deepBackground, const Color(0xFF0B0912));
  });

  test('text and key colour pairs are readable (WCAG AA)', () {
    final pairs = <String, (Color, Color, double)>{
      'text on page': (scheme.onSurface, scheme.surface, 7),
      'text on card': (scheme.onSurface, scheme.surfaceContainer, 7),
      'muted text on card': (
        scheme.onSurfaceVariant,
        scheme.surfaceContainer,
        4.5,
      ),
      'muted text on raised': (
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHigh,
        4.5,
      ),
      'button label': (scheme.onPrimary, scheme.primary, 4.5),
      'secondary label': (scheme.onSecondary, scheme.secondary, 4.5),
      'on primary container': (
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
        4.5,
      ),
      'error text on page': (scheme.error, scheme.surface, 4.5),
      'success on card': (AppColors.success, scheme.surfaceContainer, 4.5),
      'warning on card': (AppColors.warning, scheme.surfaceContainer, 4.5),
      'accent link on page': (scheme.secondary, scheme.surface, 4.5),
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

  test(
    'filled buttons are solid classic white with dark text, no gradient',
    () {
      final style = theme.filledButtonTheme.style!;

      final background = style.backgroundColor!.resolve({})!;
      final foreground = style.foregroundColor!.resolve({})!;

      expect(background, AppColors.white);
      expect(foreground, AppColors.deepBackground);
      expect(contrast(foreground, background), greaterThanOrEqualTo(12));
      expect(theme.floatingActionButtonTheme.backgroundColor, AppColors.white);
    },
  );

  test('surfaces get lighter as they are raised', () {
    final levels = [
      scheme.surfaceContainerLowest,
      scheme.surface,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
    ].map((c) => c.computeLuminance()).toList();

    expect(levels, orderedEquals([...levels]..sort()));
  });

  group('flat, hairline look', () {
    test('panels are outlined with a hairline, flat and tightly rounded', () {
      final card = theme.cardTheme;
      final shape = card.shape! as RoundedRectangleBorder;

      expect(card.elevation, 0);
      expect(shape.side.color, AppColors.outlineSoft);
      expect(shape.side.width, AppStroke.hairline);
      expect(shape.borderRadius, AppRadius.mdAll);
      expect(AppRadius.md, 12);
    });

    test('the hairline is visible but quiet', () {
      final line = contrast(scheme.outlineVariant, scheme.surface);
      final strong = contrast(scheme.outline, scheme.surface);

      expect(line, inInclusiveRange(1.15, 1.6), reason: 'hairline');
      expect(strong, greaterThanOrEqualTo(1.5), reason: 'stronger line');
      expect(strong, greaterThan(line));
    });

    test('purple selected states are a faint tint, never a solid block', () {
      for (final tint in [
        scheme.primaryContainer,
        scheme.secondaryContainer,
        scheme.tertiaryContainer,
      ]) {
        expect(tint.computeLuminance(), lessThan(0.03));
      }
      expect(scheme.primary, const Color(0xFF8B5CF6), reason: 'accent kept');
    });

    test('surface steps stay close together', () {
      final page = scheme.surface.computeLuminance();
      final top = scheme.surfaceContainerHighest.computeLuminance();
      expect(top - page, lessThan(0.02));
    });

    test('inputs are hairline outlined and turn purple only when focused', () {
      final input = theme.inputDecorationTheme;
      final idle = input.enabledBorder! as OutlineInputBorder;
      final focused = input.focusedBorder! as OutlineInputBorder;

      expect(idle.borderSide.color, AppColors.outlineSoft);
      expect(idle.borderSide.width, AppStroke.hairline);
      expect(focused.borderSide.color, AppColors.premiumPurple);
      expect(focused.borderSide.width, AppStroke.focus);
    });

    test('chips and segments are outlined and select with a faint tint', () {
      expect(theme.chipTheme.backgroundColor, Colors.transparent);
      expect(theme.chipTheme.selectedColor, AppColors.primaryContainer);
      expect(theme.chipTheme.side?.width, AppStroke.hairline);

      final segment = theme.segmentedButtonTheme.style!;
      expect(
        segment.backgroundColor!.resolve({WidgetState.selected}),
        AppColors.primaryContainer,
      );
      expect(segment.backgroundColor!.resolve({}), Colors.transparent);
    });

    test('switches use purple only when on', () {
      final track = theme.switchTheme.trackColor!;
      expect(track.resolve({WidgetState.selected}), AppColors.premiumPurple);
      expect(track.resolve({}), isNot(AppColors.premiumPurple));
      expect(
        theme.switchTheme.thumbColor!.resolve({WidgetState.selected}),
        AppColors.white,
      );
    });

    test('sheets, dialogs and snackbars carry the hairline too', () {
      final sheet = theme.bottomSheetTheme.shape! as RoundedRectangleBorder;
      final dialog = theme.dialogTheme.shape! as RoundedRectangleBorder;
      final snack = theme.snackBarTheme.shape! as RoundedRectangleBorder;

      for (final shape in [sheet, dialog, snack]) {
        expect(shape.side.color, AppColors.outlineSoft);
      }
    });

    test('buttons are compact with no shadow', () {
      final filled = theme.filledButtonTheme.style!;
      expect(
        filled.minimumSize!.resolve({}),
        const Size.fromHeight(AppSizes.control),
      );
      expect(filled.elevation!.resolve({}), 0);
      expect(AppSizes.compactControl, lessThan(AppSizes.control));
    });
  });

  group('typography', () {
    final text = theme.textTheme;

    test('headings are semibold and tight, not heavy', () {
      for (final style in [
        text.headlineLarge!,
        text.headlineMedium!,
        text.headlineSmall!,
        text.titleLarge!,
        text.titleMedium!,
      ]) {
        expect(style.fontWeight, FontWeight.w600);
      }
      expect(text.headlineSmall!.letterSpacing, lessThan(0));
      expect(text.titleLarge!.letterSpacing, lessThan(0));
    });

    test('body text is small with relaxed line height', () {
      expect(text.bodyLarge!.fontSize, 15);
      expect(text.bodyMedium!.fontSize, 14);
      expect(text.bodyMedium!.height, greaterThanOrEqualTo(1.4));
    });

    test('secondary text is muted', () {
      expect(text.bodySmall!.color, scheme.onSurfaceVariant);
    });

    test('every style uses the bundled Inter font', () {
      expect(tickyFontFamily, 'Inter');
      for (final style in [
        text.displayLarge,
        text.headlineSmall,
        text.titleMedium,
        text.bodyLarge,
        text.bodyMedium,
        text.bodySmall,
        text.labelLarge,
        text.labelSmall,
      ]) {
        expect(style!.fontFamily, 'Inter');
      }
    });

    test('the font files and licence are declared in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final file in [
        'Inter-Regular.ttf',
        'Inter-Medium.ttf',
        'Inter-SemiBold.ttf',
        'Inter-Bold.ttf',
        'OFL.txt',
      ]) {
        expect(pubspec, contains('assets/fonts/inter/$file'));
        expect(File('assets/fonts/inter/$file').existsSync(), isTrue);
      }
    });
  });

  test('exposes brand and status colours through the extension', () {
    final colors = theme.extension<TickyColors>()!;

    expect(colors.success, AppColors.success);
    expect(colors.highlight, AppColors.highlight);
    expect(colors.copyWith(coin: Colors.red).coin, Colors.red);
    expect(colors.lerp(colors, 0.5).streak, colors.streak);
  });

  test('app bar is transparent with light status bar icons', () {
    expect(theme.appBarTheme.backgroundColor, Colors.transparent);
    expect(
      theme.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
      Brightness.light,
    );
  });
}
