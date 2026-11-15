import 'package:flutter/material.dart';

/// The "Canopy" colour tokens, copied from the website's `frontend/src/index.css`: [light] is
/// Daylight (white glass on rice-paper green, for reading in full sun), [dark] is Canopy (deep
/// forest green, the brand look).
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

  /// "Needs you" (turmeric): text and dots for things waiting on the user.
  final Color harvest;

  /// Warm clay accent: unread counts and highlights that aren't errors.
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
    forest: Color(0xFF1F5A3F),
    forestLight: Color(0xFF2B7351),
    harvest: Color(0xFF8A5D00),
    terracotta: Color(0xFFA8532F),
    ink: Color(0xFF0F2A21),
    canvas: Color(0xFFEEF2E8),
    surface: Color(0xFFFFFFFF),
    overlay: Color(0x590F2A21), // rgb(15 42 33 / 0.35)
    textPrimary: Color(0xFF0F2A21),
    textSecondary: Color(0xFF4C5F56),
    success: Color(0xFF2F6E3B),
    danger: Color(0xFFB2412B),
    info: Color(0xFF2F6C7A),
  );

  /// Canopy: deep forest green with a light sage action colour. The website's index.css lists the
  /// WCAG contrast ratio of every pair; all text pairs are at least 5:1.
  static const AppColors dark = AppColors(
    forest: Color(0xFFB5CDA0),
    forestLight: Color(0xFFC9DCB8),
    harvest: Color(0xFFEFC062),
    terracotta: Color(0xFFE9A27A),
    ink: Color(0xFF0B201A),
    canvas: Color(0xFF0B201A),
    surface: Color(0xFF133429),
    overlay: Color(0xB3030A08), // rgb(3 10 8 / 0.7)
    textPrimary: Color(0xFFEAF0E7),
    textSecondary: Color(0xFFA9BBAF),
    success: Color(0xFF9ED58B),
    danger: Color(0xFFF08A73),
    info: Color(0xFF8CC7D3),
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
