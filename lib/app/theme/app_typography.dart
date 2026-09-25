import 'package:flutter/material.dart';

/// Font families bundled in `assets/fonts/` (see pubspec.yaml).
abstract final class AppFonts {
  /// Headings.
  static const String display = 'Fraunces';

  /// Body text and controls.
  static const String body = 'PlusJakartaSans';

  /// Numbers and prices.
  static const String mono = 'JetBrainsMono';

  /// Used for any character the families above don't have. Sinhala and Tamil text renders in
  /// these, so both languages look the same on every device.
  static const List<String> fallback = ['NotoSansSinhala', 'NotoSansTamil'];
}

/// Builds the app's [TextTheme]: Plus Jakarta Sans everywhere, with Fraunces for the display,
/// headline and large title styles, like the website's headings.
TextTheme buildTextTheme(TextTheme base, Color primary, Color secondary) {
  final body = base.apply(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    bodyColor: primary,
    displayColor: primary,
  );
  TextStyle? display(TextStyle? style, FontWeight weight) =>
      style?.copyWith(fontFamily: AppFonts.display, fontWeight: weight);

  return body.copyWith(
    displayLarge: display(body.displayLarge, FontWeight.w600),
    displayMedium: display(body.displayMedium, FontWeight.w600),
    displaySmall: display(body.displaySmall, FontWeight.w600),
    headlineLarge: display(body.headlineLarge, FontWeight.w600),
    headlineMedium: display(body.headlineMedium, FontWeight.w600),
    headlineSmall: display(body.headlineSmall, FontWeight.w600),
    titleLarge: display(body.titleLarge, FontWeight.w600),
    titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    bodySmall: body.bodySmall?.copyWith(color: secondary),
  );
}

extension MonoTextStyle on TextStyle {
  /// This style in JetBrains Mono, for prices, quantities and other numbers:
  /// `Theme.of(context).textTheme.titleMedium!.mono`.
  TextStyle get mono => copyWith(
    fontFamily: AppFonts.mono,
    fontFamilyFallback: AppFonts.fallback,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
