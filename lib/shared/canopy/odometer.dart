import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'motion.dart';

/// A number whose digits roll to their new value, like a mechanical counter: prices, totals and
/// counts that change in front of the user. With [rollIn] the digits start at 0 and roll up when
/// it first appears. Screen readers hear the plain text. The website's `Odometer`.
class Odometer extends ConsumerWidget {
  const Odometer({super.key, required this.text, this.style, this.rollIn = false});

  /// The formatted number ("11,200"); non-digits are shown as they are.
  final String text;
  final TextStyle? style;
  final bool rollIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = motionLevel(context, ref);
    final resolved = DefaultTextStyle.of(context).style
        .merge(style)
        .copyWith(
          fontFeatures: const [FontFeature.tabularFigures(), FontFeature('lnum')],
          height: 1,
        );
    final cellHeight = (resolved.fontSize ?? 14) * 1.2;
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < text.length; i++)
            if (RegExp(r'\d').hasMatch(text[i]))
              _Reel(
                key: ValueKey('${text.length}-$i'),
                digit: int.parse(text[i]),
                style: resolved,
                height: cellHeight,
                rollIn: rollIn,
                duration: Motion.of(level, const Duration(milliseconds: 700)),
              )
            else
              SizedBox(
                height: cellHeight,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(text[i], style: resolved),
                ),
              ),
        ],
      ),
    );
  }
}

class _Reel extends StatelessWidget {
  const _Reel({
    super.key,
    required this.digit,
    required this.style,
    required this.height,
    required this.rollIn,
    required this.duration,
  });

  final int digit;
  final TextStyle style;
  final double height;
  final bool rollIn;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRect(
        child: TweenAnimationBuilder<double>(
          // Without rollIn the reel starts at its digit; later changes roll from where it is.
          tween: Tween(begin: rollIn ? 0 : digit.toDouble(), end: digit.toDouble()),
          duration: duration,
          curve: Motion.springy,
          builder: (context, value, child) => OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: height * 10,
            child: Transform.translate(offset: Offset(0, -value * height), child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var d = 0; d < 10; d++)
                SizedBox(
                  height: height,
                  child: Center(child: Text('$d', style: style)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
