import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../issues/data/advisory.dart';
import '../../application/trace_format.dart';

/// How the AI reached its advice, for the officer deciding on it: which agents ran, how long each
/// took, and what each produced. It starts closed, because most reviews don't need it; opening
/// it shows one card per step.
///
/// Each agent's output has its own shape, so it is shown as labelled values worked out from the
/// keys it recorded, never as raw JSON. What a step was given is behind a second, smaller
/// "Show what this step was given". Mirrors the website's `AgentTracePanel`.
class AgentTracePanel extends ConsumerWidget {
  const AgentTracePanel({super.key, required this.trace});

  final AgentTrace trace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (trace.steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    // A Material rather than a DecoratedBox: the tiles inside paint their ink on the nearest
    // Material, and a coloured box in between would hide it.
    return Material(
      color: colors.canvas,
      borderRadius: BorderRadius.circular(kRadius),
      child: ExpansionTile(
        key: const Key('agent-trace'),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: Gaps.md),
        childrenPadding: const EdgeInsets.fromLTRB(Gaps.md, 0, Gaps.md, Gaps.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(l10n.issuesAgentTraceTitle, style: textTheme.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: Gaps.xs),
          child: Wrap(
            spacing: Gaps.sm,
            runSpacing: Gaps.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusChip(status: trace.status),
              Text(
                l10n.officerTraceStepsCount(format.number(trace.steps.length)),
                style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        children: [
          Text(
            l10n.issuesAgentTraceRanOn(format.dateTime(trace.startedAt)),
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Gaps.sm),
          for (final (index, step) in trace.steps.indexed) ...[
            _StepCard(step: step),
            if (index < trace.steps.length - 1) const SizedBox(height: Gaps.sm),
          ],
        ],
      ),
    );
  }
}

/// `Completed`, `Failed` or `Running`, written out and given an icon so it isn't only a colour.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (status) {
      'Completed' => StatusBadge(
        label: l10n.issuesAgentTraceStatusCompleted,
        tone: BadgeTone.success,
        icon: Icons.check_circle_outline,
      ),
      'Failed' => StatusBadge(
        label: l10n.issuesAgentTraceStatusFailed,
        tone: BadgeTone.danger,
        icon: Icons.error_outline,
      ),
      'Running' => StatusBadge(
        label: l10n.issuesAgentTraceStatusRunning,
        tone: BadgeTone.info,
        icon: Icons.sync,
      ),
      _ => StatusBadge(label: status),
    };
  }
}

IconData _agentIcon(String agentName) => switch (agentName) {
  'PlannerAgent' => Icons.psychology_outlined,
  'CropAnalysisAgent' => Icons.search,
  'WeatherAgent' => Icons.wb_sunny_outlined,
  'ValidationAgent' => Icons.verified_user_outlined,
  'ImageClassificationAgent' => Icons.image_search,
  'PhotoTriageAgent' => Icons.fact_check_outlined,
  _ => Icons.smart_toy_outlined,
};

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final AgentStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final duration = stepDuration(step);
    final output = step.output;
    final input = step.input;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Gaps.sm + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_agentIcon(step.agentName), size: 20, color: colors.forest),
                const SizedBox(width: Gaps.sm),
                Expanded(
                  child: Text(agentDisplayName(step.agentName), style: textTheme.titleSmall),
                ),
                if (duration != null)
                  Text(
                    _durationLabel(l10n, duration),
                    style: textTheme.bodySmall?.mono.copyWith(color: colors.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: Gaps.xs),
            _StatusChip(status: step.status),
            const SizedBox(height: Gaps.sm),
            if (output == null || output == '')
              Text(
                l10n.issuesAgentTraceNoOutput,
                style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              )
            else
              TraceValue(value: output),
            if (input != null && input != '') ...[
              const SizedBox(height: Gaps.xs),
              // A second, smaller fold: what a step was given is rarely what the officer needs.
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: Gaps.sm),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  title: Text(
                    l10n.issuesAgentTraceShowInput,
                    style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                  children: [TraceValue(value: input)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _durationLabel(AppLocalizations l10n, Duration duration) {
    final ms = duration.inMilliseconds;
    return ms < 1000
        ? l10n.officerTraceDurationMs(ms)
        : l10n.officerTraceDurationSeconds((ms / 1000).toStringAsFixed(1));
  }
}

/// Whatever an agent recorded, as labelled values. A map becomes label and value rows, a list
/// becomes bullets (the first few, then "+N more"), and long text is cut. Nesting stops after a
/// few levels so a deep structure still reads on a phone.
class TraceValue extends StatelessWidget {
  const TraceValue({super.key, required this.value, this.depth = 0});

  final Object? value;
  final int depth;

  /// The most list items shown before "+N more".
  static const int maxListItems = 5;

  /// Nesting deeper than this is written out as text.
  static const int maxDepth = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: colors.textSecondary);
    final value = this.value;
    if (value == null || value == '') {
      return Text('—', style: muted);
    }
    if (value is bool) {
      return Text(value ? l10n.officerTraceYes : l10n.officerTraceNo, style: textTheme.bodyMedium);
    }
    if (value is num) {
      return Text(formatTraceNumber(value), style: textTheme.bodyMedium!.mono);
    }
    if (value is List) {
      if (value.isEmpty) {
        return Text('—', style: muted);
      }
      if (depth >= maxDepth) {
        return Text(clipTraceText(value.join(', ')), style: textTheme.bodyMedium);
      }
      final shown = value.take(maxListItems).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: Gaps.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: textTheme.bodyMedium),
                  Expanded(
                    child: TraceValue(value: item, depth: depth + 1),
                  ),
                ],
              ),
            ),
          if (value.length > shown.length)
            Text(l10n.officerTraceMore(value.length - shown.length), style: muted),
        ],
      );
    }
    if (value is Map) {
      if (value.isEmpty) {
        return Text('—', style: muted);
      }
      if (depth >= maxDepth) {
        return Text(clipTraceText(value.toString()), style: textTheme.bodyMedium);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in value.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: Gaps.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    humanizeKey('${entry.key}'),
                    style: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
                  ),
                  TraceValue(value: entry.value, depth: depth + 1),
                ],
              ),
            ),
        ],
      );
    }
    return Text(clipTraceText('$value'), style: textTheme.bodyMedium);
  }
}
