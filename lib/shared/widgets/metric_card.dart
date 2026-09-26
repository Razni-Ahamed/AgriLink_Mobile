import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_typography.dart';

/// Which accent a [MetricCard] uses, like the website's `MetricsCard` tones.
enum MetricTone { forest, harvest, terracotta }

/// One number with a label and an icon, for the officer and admin dashboards. Give it an
/// [onTap] to make the whole card a button (the label is then read out as one).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = MetricTone.forest,
    this.onTap,
  });

  final String label;

  /// Already formatted, so the caller decides on thousands separators and units.
  final String value;
  final IconData icon;
  final MetricTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final accent = switch (tone) {
      MetricTone.forest => colors.forest,
      MetricTone.harvest => colors.harvest,
      MetricTone.terracotta => colors.terracotta,
    };
    final content = Padding(
      padding: const EdgeInsets.all(Gaps.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(Gaps.sm),
            decoration: BoxDecoration(
              color: colors.tint(accent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: Gaps.sm),
          Text(label, style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: textTheme.headlineSmall!.mono),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: '$label: $value',
      button: onTap != null,
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: onTap == null
            ? content
            : InkWell(borderRadius: BorderRadius.circular(kRadius), onTap: onTap, child: content),
      ),
    );
  }
}

/// Two cards to a row on a phone. A row is as tall as its taller card, so long Sinhala and Tamil
/// labels never overflow.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: Gaps.sm),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
            ],
          ),
        ),
      );
      if (i + 2 < children.length) {
        rows.add(const SizedBox(height: Gaps.sm));
      }
    }
    return Column(children: rows);
  }
}
