import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ticky/core/theme/app_colors.dart';
import 'package:ticky/core/theme/app_text_theme.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';

/// Ticky is dark-only: there is one theme.
///
/// The look is flat and calm: a near-black page, panels drawn with a hairline
/// instead of a fill, white primary buttons, and purple only as an accent
/// (focus, switches, selected states, links).
abstract final class AppTheme {
  static final ColorScheme colorScheme = const ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.premiumPurple,
    // Dark text on the purple passes WCAG AA (4.6:1); light text would not.
    onPrimary: AppColors.deepBackground,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.softViolet,
    onSecondary: AppColors.deepBackground,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    tertiary: AppColors.highlight,
    onTertiary: AppColors.deepBackground,
    tertiaryContainer: AppColors.tertiaryContainer,
    onTertiaryContainer: AppColors.onPrimaryContainer,
    error: AppColors.error,
    onError: AppColors.deepBackground,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.deepBackground,
    onSurface: AppColors.white,
    onSurfaceVariant: AppColors.textMuted,
    surfaceDim: AppColors.surfaceLowest,
    surfaceBright: AppColors.surfaceHighest,
    surfaceContainerLowest: AppColors.surfaceLowest,
    surfaceContainerLow: AppColors.surfaceLow,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainerHighest: AppColors.surfaceHighest,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineSoft,
    inverseSurface: AppColors.white,
    onInverseSurface: AppColors.deepBackground,
    inversePrimary: Color(0xFF7C3AED),
    surfaceTint: AppColors.premiumPurple,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static final ThemeData dark = _build();

  static ThemeData _build() {
    final scheme = colorScheme;
    final text = buildTextTheme(scheme);
    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.mdAll);
    const hairline = BorderSide(
      color: AppColors.outlineSoft,
      width: AppStroke.hairline,
    );

    OutlineInputBorder inputBorder(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: text,
      extensions: const [TickyColors.dark],
      visualDensity: VisualDensity.standard,
      // Quiet touch feedback: a faint wash, no sparkle.
      splashFactory: InkRipple.splashFactory,
      splashColor: AppColors.white.withValues(alpha: 0.05),
      highlightColor: AppColors.white.withValues(alpha: 0.03),
      hoverColor: AppColors.white.withValues(alpha: 0.04),
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
        titleTextStyle: text.titleMedium,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.deepBackground,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      // Panels are outlined, not filled: a hairline and almost no fill.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: hairline,
        ),
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
      // Primary actions are solid, classic white with dark text.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.deepBackground,
          disabledBackgroundColor: AppColors.white.withValues(alpha: 0.12),
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
          foregroundColor: scheme.secondary,
          shape: buttonShape,
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.deepBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
      ),
      // Outlined fields: a hairline, a faint fill, purple only when focused.
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
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(
          color: scheme.outlineVariant,
          width: AppStroke.hairline,
        ),
        labelStyle: text.labelLarge?.copyWith(fontSize: 13.5),
        shape: const StadiumBorder(),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant, width: AppStroke.hairline),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.white
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHigh,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outlineVariant,
        ),
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
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: hairline,
        ),
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
            top: Radius.circular(AppRadius.lg),
          ),
          side: hairline,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: text.bodyMedium,
        actionTextColor: scheme.secondary,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: hairline,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: AppRadius.smAll,
          border: Border.fromBorderSide(hairline),
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onSurface),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.secondary,
        selectionColor: scheme.primary.withValues(alpha: 0.35),
        selectionHandleColor: scheme.secondary,
      ),
    );
  }
}
