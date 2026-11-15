import 'package:flutter/material.dart';

/// Font families bundled in `assets/fonts/` (see pubspec.yaml).
abstract final class AppFonts {
  /// Headings: Abhaya Libre, a serif with Latin and Sinhala in one family.
  static const String display = 'AbhayaLibre';

  /// Body text and controls: Yaldevi, Latin and Sinhala.
  static const String body = 'Yaldevi';

  /// Numbers and prices.
  static const String mono = 'JetBrainsMono';

  /// Used for any character the families above don't have: Tamil everywhere, and Sinhala in the
  /// mono face.
  static const List<String> fallback = ['NotoSansSinhala', 'NotoSansTamil'];
}

/// Builds the app's [TextTheme]: Yaldevi everywhere, with Abhaya Libre for the display, headline
/// and large title styles, like the website's headings. Abhaya Libre's default figures are
/// old-style (they rise and fall), so headings ask for lining figures.
TextTheme buildTextTheme(TextTheme base, Color primary, Color secondary) {
  final body = base.apply(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    bodyColor: primary,
    displayColor: primary,
  );
  TextStyle? display(TextStyle? style, FontWeight weight) => style?.copyWith(
    fontFamily: AppFonts.display,
    fontWeight: weight,
    fontFeatures: const [FontFeature('lnum')],
  );

  return body.copyWith(
    displayLarge: display(body.displayLarge, FontWeight.w800),
    displayMedium: display(body.displayMedium, FontWeight.w800),
    displaySmall: display(body.displaySmall, FontWeight.w700),
    headlineLarge: display(body.headlineLarge, FontWeight.w700),
    headlineMedium: display(body.headlineMedium, FontWeight.w700),
    headlineSmall: display(body.headlineSmall, FontWeight.w700),
    titleLarge: display(body.titleLarge, FontWeight.w700),
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
