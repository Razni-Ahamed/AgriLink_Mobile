import 'package:flutter/material.dart';

/// The "Organic Bento" colour tokens, copied from the website's `frontend/src/index.css`.
///
/// Every colour in the app comes from here, either directly (`context.colors.harvest`) or
/// through the Material [ColorScheme] built from these tokens in `app_theme.dart`. No screen
/// hardcodes a colour. Adding a token means adding it to both [light] and [dark].
///
/// Like the website, [forest] inverts from a deep green (light) to a luminous green (dark), and
/// [surface] flips the other way, so a forest fill with surface-coloured text stays readable in
/// both modes without any per-screen dark-mode checks.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.forest,
    required this.forestLight,
    required this.harvest,
    required this.terracotta,
    required this.ink,
    required this.canvas,
    required this.surface,
    required this.overlay,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.danger,
    required this.info,
  });

  /// Primary brand colour: filled buttons, the active tab, links.
  final Color forest;
  final Color forestLight;

  /// Secondary gold accent. Put [ink] text on it, never [forest].
  final Color harvest;

  /// Warm accent for highlights and warnings that aren't errors.
  final Color terracotta;

  /// Text on a bright accent fill such as [harvest].
  final Color ink;

  /// The page background behind cards.
  final Color canvas;

  /// Cards, sheets, dialogs and app bars.
  final Color surface;

  /// Scrim behind dialogs and bottom sheets.
  final Color overlay;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color danger;
  final Color info;

  /// Soft 1 px borders around cards and inputs.
  Color get border => textPrimary.withValues(alpha: 0.10);

  /// A stronger border, for focused or selected outlines.
  Color get borderStrong => textSecondary.withValues(alpha: 0.45);

  /// A light wash of a state colour, for badge and banner backgrounds.
  Color tint(Color color) => Color.alphaBlend(color.withValues(alpha: 0.14), surface);

  static const AppColors light = AppColors(
    forest: Color(0xFF1F4D36),
    forestLight: Color(0xFF4A7C59),
    harvest: Color(0xFFD9A441),
    terracotta: Color(0xFFC4623B),
    ink: Color(0xFF1F4D36),
    canvas: Color(0xFFFAF7F0),
    surface: Color(0xFFFFFDF9),
    overlay: Color(0x4D1F4D36), // rgb(31 77 54 / 0.3)
    textPrimary: Color(0xFF26201A),
    textSecondary: Color(0xFF6B6259),
    success: Color(0xFF3E7A4F),
    danger: Color(0xFFB84C3C),
    info: Color(0xFF3E7A82),
  );

  /// "Night harvest": green-tinted charcoal surfaces and warm parchment text. The website's
  /// index.css lists the WCAG contrast ratio of every pair; all text pairs are at least 6:1.
  static const AppColors dark = AppColors(
    forest: Color(0xFF7CBE8C),
    forestLight: Color(0xFF9ED4AA),
    harvest: Color(0xFFE8BD60),
    terracotta: Color(0xFFDD7D55),
    ink: Color(0xFF10170F),
    canvas: Color(0xFF0F1512),
    surface: Color(0xFF17201A),
    overlay: Color(0xA8060A08), // rgb(6 10 8 / 0.66)
    textPrimary: Color(0xFFE9E4D9),
    textSecondary: Color(0xFFA49C8E),
    success: Color(0xFF74C489),
    danger: Color(0xFFE8806C),
    info: Color(0xFF66B3BB),
  );

  @override
  AppColors copyWith({
    Color? forest,
    Color? forestLight,
    Color? harvest,
    Color? terracotta,
    Color? ink,
    Color? canvas,
    Color? surface,
    Color? overlay,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? danger,
    Color? info,
  }) {
    return AppColors(
      forest: forest ?? this.forest,
      forestLight: forestLight ?? this.forestLight,
      harvest: harvest ?? this.harvest,
      terracotta: terracotta ?? this.terracotta,
      ink: ink ?? this.ink,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      overlay: overlay ?? this.overlay,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppColors(
      forest: Color.lerp(forest, other.forest, t)!,
      forestLight: Color.lerp(forestLight, other.forestLight, t)!,
      harvest: Color.lerp(harvest, other.harvest, t)!,
      terracotta: Color.lerp(terracotta, other.terracotta, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  /// The current theme's colour tokens: `context.colors.forest`.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
