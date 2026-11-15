import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import 'motion.dart';

/// Liquid glass: whatever is behind turns into coloured light (blur), with a sheen and three rims
/// (a bright top line, a faint outline, a dark bottom line) so it reads as thick glass rather than
/// grey fog. The website's `.glass` recipe.
///
/// Glass is for the frame (the tab bar, banners' strips, sheets over photos); lists and forms stay
/// on solid surfaces. With Lite or Off motion it draws a solid panel instead: blur is the most
/// expensive thing a cheap phone draws.
class GlassSurface extends ConsumerWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.onPhoto = false,
    this.padding,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Dark glass for a panel floating on a darkened photo, whatever the theme.
  final bool onPhoto;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blur = motionLevel(context, ref) == MotionLevel.full;

    final Color tint;
    final Color sheen;
    final Color rim;
    final Color rimTop;
    if (onPhoto) {
      tint = const Color(0xFF0A1E18).withValues(alpha: blur ? 0.45 : 0.88);
      sheen = Colors.white.withValues(alpha: 0.12);
      rim = Colors.white.withValues(alpha: 0.16);
      rimTop = Colors.white.withValues(alpha: 0.28);
    } else if (isDark) {
      tint = blur ? const Color(0xFF102C23).withValues(alpha: 0.55) : colors.surface;
      sheen = const Color(0xFFEAF0E7).withValues(alpha: 0.10);
      rim = Colors.white.withValues(alpha: 0.12);
      rimTop = Colors.white.withValues(alpha: 0.28);
    } else {
      tint = blur ? Colors.white.withValues(alpha: 0.66) : colors.surface;
      sheen = Colors.white.withValues(alpha: 0.55);
      rim = Colors.white.withValues(alpha: 0.75);
      rimTop = Colors.white.withValues(alpha: 0.95);
    }

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.46],
          colors: [Color.alphaBlend(sheen, tint), tint],
        ),
        border: Border.all(color: rim),
      ),
      child: Stack(
        children: [
          // The bright top rim where light catches the edge.
          Positioned(left: 12, right: 12, top: 0, child: Container(height: 1, color: rimTop)),
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );

    // The shadow is painted only outside the panel, as CSS's box-shadow is. A BoxShadow would
    // also sit under the see-through glass and show as a dark block inside it.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _OuterShadowPainter(
              borderRadius: borderRadius,
              color: Colors.black.withValues(alpha: isDark || onPhoto ? 0.45 : 0.14),
            ),
          ),
        ),
        if (blur)
          ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22), child: panel),
          )
        else
          panel,
      ],
    );
  }
}

/// A soft shadow below a rounded panel, drawn only outside the panel's shape.
class _OuterShadowPainter extends CustomPainter {
  _OuterShadowPainter({required this.borderRadius, required this.color});

  final BorderRadius borderRadius;
  final Color color;

  static const double _blur = 40;
  static const double _spread = -24;
  static const Offset _offset = Offset(0, 18);

  @override
  void paint(Canvas canvas, Size size) {
    final shape = borderRadius.toRRect(Offset.zero & size);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(_blur * 2)),
      Path()..addRRect(shape),
    );
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        shape.shift(_offset).inflate(_spread),
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, Shadow.convertRadiusToSigma(_blur)),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) =>
      old.color != color || old.borderRadius != borderRadius;
}
