import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Corner radius for cards, buttons, inputs and sheets.
const double kRadius = 16;

/// Standard spacing steps. Use these instead of arbitrary numbers.
abstract final class Gaps {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// The whole Material theme, built from [AppColors]. Screens read colours through
/// `Theme.of(context).colorScheme` or `context.colors`, never with literal values.
abstract final class AppTheme {
  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.forest,
      onPrimary: c.surface,
      primaryContainer: c.tint(c.forest),
      onPrimaryContainer: isDark ? c.forestLight : c.forest,
      secondary: c.harvest,
      onSecondary: c.ink,
      secondaryContainer: c.tint(c.harvest),
      onSecondaryContainer: c.textPrimary,
      tertiary: c.terracotta,
      onTertiary: isDark ? c.ink : c.surface,
      tertiaryContainer: c.tint(c.terracotta),
      onTertiaryContainer: c.textPrimary,
      error: c.danger,
      onError: c.surface,
      errorContainer: c.tint(c.danger),
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: Color.alphaBlend(c.canvas.withValues(alpha: 0.5), c.surface),
      surfaceContainerHigh: c.canvas,
      surfaceContainerHighest: Color.alphaBlend(c.textPrimary.withValues(alpha: 0.06), c.canvas),
      outline: c.borderStrong,
      outlineVariant: c.border,
      shadow: Colors.black,
      scrim: c.overlay,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.canvas,
      inversePrimary: isDark ? AppColors.light.forest : AppColors.dark.forest,
      surfaceTint: Colors.transparent,
    );

    final base = isDark ? Typography.material2021().white : Typography.material2021().black;
    final textTheme = buildTextTheme(base, c.textPrimary, c.textSecondary);
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius));
    // 48 dp minimum touch target for every button.
    const buttonSize = Size(64, 48);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 12);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadius),
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c],
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
          side: BorderSide(color: c.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: rounded,
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: rounded,
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: rounded,
          foregroundColor: c.forest,
          side: BorderSide(color: c.borderStrong),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonSize,
          shape: rounded,
          foregroundColor: c.forest,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: inputBorder(c.borderStrong),
        enabledBorder: inputBorder(c.borderStrong),
        focusedBorder: inputBorder(c.forest, 2),
        errorBorder: inputBorder(c.danger),
        focusedErrorBorder: inputBorder(c.danger, 2),
        disabledBorder: inputBorder(c.border),
        labelStyle: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        side: BorderSide(color: c.border),
        backgroundColor: c.surface,
        selectedColor: c.tint(c.forest),
        labelStyle: textTheme.labelLarge,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: buttonSize,
          selectedBackgroundColor: c.forest,
          selectedForegroundColor: c.surface,
          side: BorderSide(color: c.borderStrong),
          shape: rounded,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.tint(c.forest),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? c.forest : c.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected) ? c.forest : c.textSecondary,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        minVerticalPadding: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.overlay,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius + 8)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        barrierColor: c.overlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius + 4)),
        titleTextStyle: textTheme.titleLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.canvas),
        actionTextColor: isDark ? AppColors.light.harvest : c.harvest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.forest),
      badgeTheme: BadgeThemeData(backgroundColor: c.terracotta, textColor: c.surface),
    );
  }
}
