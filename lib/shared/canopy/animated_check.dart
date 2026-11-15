import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'motion.dart';

/// A tick that draws itself, for "sent", "approved", "done". With motion off it simply appears.
class AnimatedCheck extends ConsumerWidget {
  const AnimatedCheck({super.key, this.size = 20, this.color, this.strokeWidth = 2.6});

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = motionLevel(context, ref);
    final tint = color ?? IconTheme.of(context).color ?? Colors.white;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: level == MotionLevel.off ? 1 : 0, end: 1),
      duration: Motion.of(level, const Duration(milliseconds: 350)),
      curve: Motion.out,
      builder: (context, drawn, _) => CustomPaint(
        size: Size.square(size),
        painter: _CheckPainter(drawn: drawn, color: tint, strokeWidth: strokeWidth),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.drawn, required this.color, required this.strokeWidth});

  final double drawn;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()
      ..moveTo(5 * s, 12.5 * s)
      ..lineTo(9.5 * s, 17 * s)
      ..lineTo(19 * s, 7.5 * s);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * drawn),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.drawn != drawn || old.color != color;
}

/// Steps of a slow piece of work: done steps get a drawn tick, the current one a spinning ring,
/// later ones a quiet circle. [current] is the step in progress; `steps.length` means all done.
class StageList extends StatelessWidget {
  const StageList({super.key, required this.steps, required this.current});

  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 24,
                  child: i < current
                      ? DecoratedBox(
                          decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                          child: Center(
                            child: AnimatedCheck(size: 15, color: scheme.onPrimary, strokeWidth: 3),
                          ),
                        )
                      : i == current
                      ? CircularProgressIndicator(strokeWidth: 2.4, color: scheme.primary)
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.outlineVariant, width: 1.6),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    steps[i],
                    style: textTheme.bodyMedium?.copyWith(
                      color: i <= current ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
