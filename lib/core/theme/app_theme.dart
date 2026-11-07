import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ticky/core/theme/app_colors.dart';
import 'package:ticky/core/theme/app_text_theme.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';

/// Ticky has a light and a dark theme; the user picks System, Light or Dark in
/// Settings.
///
/// Light: a pale lavender page, white content, big rounded pastel tiles and
/// near-black for the strong moments (primary buttons, selected pills).
/// Dark: the same shapes on a deep violet-black page with muted tiles.
/// Purple is a quiet accent for focus, switches and links in both.
///
/// "Ink" (primary button, selected pill, tooltips) is `inverseSurface`, and the
/// text on it is `onInverseSurface`, so widgets never hard-code black or white.
abstract final class AppTheme {
  static final ColorScheme lightScheme = const ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.premiumPurple,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.softViolet,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    tertiary: AppColors.highlight,
    onTertiary: AppColors.ink,
    tertiaryContainer: AppColors.tertiaryContainer,
    onTertiaryContainer: AppColors.onPrimaryContainer,
    error: AppColors.error,
    onError: AppColors.white,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.canvas,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.textMuted,
    surfaceDim: AppColors.fillStrong,
    surfaceBright: AppColors.white,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.white,
    surfaceContainer: AppColors.white,
    surfaceContainerHigh: AppColors.fill,
    surfaceContainerHighest: AppColors.fillStrong,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineSoft,
    inverseSurface: AppColors.ink,
    onInverseSurface: AppColors.white,
    inversePrimary: AppColors.highlight,
    surfaceTint: AppColors.premiumPurple,
    shadow: AppColors.ink,
    scrim: AppColors.ink,
  );

  static final ColorScheme darkScheme = const ColorScheme(
    brightness: Brightness.dark,
    primary: AppDarkColors.premiumPurple,
    onPrimary: AppDarkColors.onPrimary,
    primaryContainer: AppDarkColors.primaryContainer,
    onPrimaryContainer: AppDarkColors.onPrimaryContainer,
    secondary: AppColors.softViolet,
    onSecondary: AppDarkColors.onPrimary,
    secondaryContainer: AppDarkColors.secondaryContainer,
    onSecondaryContainer: AppDarkColors.onPrimaryContainer,
    tertiary: AppColors.highlight,
    onTertiary: AppDarkColors.onPrimary,
    tertiaryContainer: AppDarkColors.tertiaryContainer,
    onTertiaryContainer: AppDarkColors.onPrimaryContainer,
    error: AppDarkColors.error,
    onError: AppDarkColors.onPrimary,
    errorContainer: AppDarkColors.errorContainer,
    onErrorContainer: AppDarkColors.onErrorContainer,
    surface: AppDarkColors.canvas,
    onSurface: AppDarkColors.text,
    onSurfaceVariant: AppDarkColors.textMuted,
    surfaceDim: AppDarkColors.canvas,
    surfaceBright: AppDarkColors.fillStrong,
    surfaceContainerLowest: AppDarkColors.card,
    surfaceContainerLow: AppDarkColors.card,
    surfaceContainer: AppDarkColors.card,
    surfaceContainerHigh: AppDarkColors.fill,
    surfaceContainerHighest: AppDarkColors.fillStrong,
    outline: AppDarkColors.outline,
    outlineVariant: AppDarkColors.outlineSoft,
    inverseSurface: AppDarkColors.text,
    onInverseSurface: AppDarkColors.onPrimary,
    inversePrimary: Color(0xFF7456E8),
    surfaceTint: AppDarkColors.premiumPurple,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = isLight ? lightScheme : darkScheme;
    final ink = scheme.inverseSurface;
    final onInk = scheme.onInverseSurface;
    final text = buildTextTheme(scheme);
    const buttonShape = StadiumBorder();
    OutlineInputBorder inputBorder(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: text,
      extensions: [isLight ? TickyColors.light : TickyColors.dark],
      visualDensity: VisualDensity.standard,
      // Soft touch feedback: a faint lavender wash.
      splashFactory: InkRipple.splashFactory,
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.04),
      hoverColor: scheme.primary.withValues(alpha: 0.04),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isLight
              ? Brightness.dark
              : Brightness.light,
        ),
      ),
      // Cards are white and softly rounded, with no outline.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: AppStroke.hairline,
        space: AppStroke.hairline,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      // Primary actions are solid near-black with white text, fully rounded.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: onInk,
          disabledBackgroundColor: ink.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size.fromHeight(AppSizes.control),
          shape: buttonShape,
          elevation: 0,
          textStyle: text.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.control),
          shape: buttonShape,
          elevation: 0,
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.control),
          shape: buttonShape,
          side: BorderSide(color: scheme.outline, width: AppStroke.hairline),
          foregroundColor: scheme.onSurface,
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: buttonShape,
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: const CircleBorder(),
      ),
      // Fields: a soft white fill with a faint border, purple when focused.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        border: inputBorder(scheme.outlineVariant, AppStroke.hairline),
        enabledBorder: inputBorder(scheme.outlineVariant, AppStroke.hairline),
        focusedBorder: inputBorder(scheme.primary, AppStroke.focus),
        errorBorder: inputBorder(scheme.error, AppStroke.hairline),
        focusedErrorBorder: inputBorder(scheme.error, AppStroke.focus),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: ink,
        secondarySelectedColor: ink,
        side: BorderSide.none,
        labelStyle: text.labelLarge?.copyWith(
          fontSize: 14,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? onInk
                : scheme.onSurface,
          ),
        ),
        shape: const StadiumBorder(),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: const WidgetStatePropertyAll(BorderSide.none),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? ink
                : scheme.surfaceContainerLow,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? onInk
                : scheme.onSurfaceVariant,
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: scheme.outline, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: text.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: onInk),
        actionTextColor: scheme.inversePrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: ink, borderRadius: AppRadius.smAll),
        textStyle: text.bodySmall?.copyWith(color: onInk),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.25),
        selectionHandleColor: scheme.primary,
      ),
    );
  }
}
