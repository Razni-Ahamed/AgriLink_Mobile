import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'motion.dart';

/// How far a crop is through its season, from its planting and expected harvest dates.
class SeasonProgress {
  const SeasonProgress({
    required this.day,
    required this.total,
    required this.fraction,
    required this.daysLeft,
  });

  factory SeasonProgress.of(DateTime planting, DateTime harvest, [DateTime? now]) {
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    final start = day(planting);
    final end = day(harvest);
    final today = day(now ?? DateTime.now());
    final total = math.max(1, end.difference(start).inDays);
    final elapsed = today.difference(start).inDays;
    return SeasonProgress(
      day: (elapsed + 1).clamp(0, total),
      total: total,
      fraction: (elapsed / total).clamp(0.0, 1.0),
      daysLeft: end.difference(today).inDays,
    );
  }

  /// Days since planting, counting the planting day as day 1.
  final int day;
  final int total;

  /// 0–1.
  final double fraction;

  /// Negative once the harvest date has passed.
  final int daysLeft;
}

/// A crop's season as a vine that grows to today, with leaves sprouting at each fifth of the
/// season and a dashed ring at the end for the harvest. Grows once when it appears; with motion
/// off it is simply drawn. The website's `SeasonVine`.
class SeasonVine extends ConsumerWidget {
  const SeasonVine({
    super.key,
    required this.fraction,
    required this.label,
    this.color,
    this.trackColor,
  });

  final double fraction;

  /// Read by screen readers ("Paddy: day 64 of 105").
  final String label;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = motionLevel(context, ref);
    final vineColor = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: level == MotionLevel.off ? fraction : 0, end: fraction),
        duration: Motion.of(level, const Duration(milliseconds: 1400)),
        curve: const Cubic(0.3, 0.7, 0.2, 1),
        builder: (context, grown, _) => CustomPaint(
          size: const Size(double.infinity, 44),
          painter: _VinePainter(
            grown: grown,
            color: vineColor,
            track: trackColor ?? vineColor.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}

class _VinePainter extends CustomPainter {
  _VinePainter({required this.grown, required this.color, required this.track});

  final double grown;
  final Color color;
  final Color track;

  static const _leaves = [0.2, 0.4, 0.6, 0.8];

  double _y(double x, Size size) =>
      size.height / 2 + 9 * math.sin((x / size.width) * math.pi * 2.6);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i <= 60; i++) {
      final x = 6 + (i / 60) * (size.width - 12);
      i == 0 ? path.moveTo(x, _y(x, size)) : path.lineTo(x, _y(x, size));
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      path,
      stroke
        ..color = track
        ..strokeWidth = 3,
    );

    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * grown),
      stroke
        ..color = color
        ..strokeWidth = 3.4,
    );

    final leaf = Paint()..color = color;
    for (var i = 0; i < _leaves.length; i++) {
      final at = _leaves[i];
      if (at > grown) continue;
      // Each leaf pops in over the stretch of growth just after the vine reaches it.
      final pop = ((grown - at) / 0.08).clamp(0.0, 1.0);
      final point = metric.getTangentForOffset(metric.length * at)!.position;
      final up = i.isEven ? -1.0 : 1.0;
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.scale(pop);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(4, up * 12, 13, up * 13)
          ..quadraticBezierTo(12, up * 3, 0, 0),
        leaf,
      );
      canvas.restore();
    }

    final end = metric.getTangentForOffset(metric.length)!.position;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = track.withValues(alpha: 0.9);
    canvas.drawCircle(end, 6, ring);
  }

  @override
  bool shouldRepaint(_VinePainter old) =>
      old.grown != grown || old.color != color || old.track != track;
}
