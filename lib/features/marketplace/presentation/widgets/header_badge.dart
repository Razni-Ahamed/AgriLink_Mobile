import 'package:flutter/material.dart';

/// The status badge at the end of a card's title row. It keeps to the right edge and takes up
/// to half the screen's width, so a long Sinhala or Tamil label stays whole where it fits, and
/// wraps rather than running off the edge where it doesn't.
class HeaderBadge extends StatelessWidget {
  const HeaderBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.5),
    child: child,
  );
}
