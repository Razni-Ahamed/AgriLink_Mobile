import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/format/formatters.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/admin_providers.dart';
import '../data/admin_models.dart';

/// The admin's home: platform-wide numbers, and a simple bar chart of the totals. Pull down to
/// refresh.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(adminMetricsProvider);
    return Scaffold(
      appBar: AgriLinkAppBar(title: context.l10n.ordersAdminDashboardTitle),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminMetricsProvider);
          try {
            await ref.read(adminMetricsProvider.future);
          } on Object {
            // The screen shows the error itself; the spinner only has to stop.
          }
        },
        child: AsyncValueView(
          value: metrics,
          onRetry: () => ref.invalidate(adminMetricsProvider),
          data: (data) => _Dashboard(metrics: data),
        ),
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.metrics});

  final AdminMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(formattersProvider);
    String n(int value) => format.number(value);
    void open(String path) => context.go(path);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        MetricGrid(
          children: [
            MetricCard(
              key: const Key('metric-users'),
              label: l10n.ordersAdminTotalUsers,
              value: n(metrics.totalUsers),
              icon: Icons.group_outlined,
              onTap: () => open(AppRoutes.adminUsers),
            ),
            MetricCard(
              label: l10n.ordersAdminTotalFarms,
              value: n(metrics.totalFarms),
              icon: Icons.agriculture_outlined,
            ),
            MetricCard(
              label: l10n.ordersAdminTotalCrops,
              value: n(metrics.totalCrops),
              icon: Icons.grass_outlined,
            ),
            // The three issue numbers open the full list, like the website: "reported" is a
            // lifetime total, so it isn't the same thing as the pending queue.
            MetricCard(
              key: const Key('metric-issues-reported'),
              label: l10n.ordersAdminIssuesReported,
              value: n(metrics.issuesReported),
              icon: Icons.report_outlined,
              onTap: () => open(AppRoutes.allIssues),
            ),
            MetricCard(
              key: const Key('metric-issues-pending'),
              label: l10n.ordersAdminIssuesPending,
              value: n(metrics.issuesPending),
              icon: Icons.warning_amber_outlined,
              tone: MetricTone.harvest,
              onTap: () => open(AppRoutes.pendingIssues),
            ),
            MetricCard(
              label: l10n.ordersAdminIssuesResolved,
              value: n(metrics.issuesResolved),
              icon: Icons.check_circle_outline,
              onTap: () => open(AppRoutes.allIssues),
            ),
          ],
        ),
        const SizedBox(height: Gaps.sm),
        MetricCard(
          key: const Key('metric-harvest'),
          label: l10n.ordersAdminHarvestVolume,
          value: format.kilograms(l10n, metrics.harvestVolumeSoldThisMonth),
          icon: Icons.scale_outlined,
          tone: MetricTone.terracotta,
        ),
        const SizedBox(height: Gaps.md),
        _TotalsChart(
          title: l10n.ordersAdminPlatformTotals,
          bars: [
            (l10n.ordersAdminChartUsers, metrics.totalUsers),
            (l10n.ordersAdminChartFarms, metrics.totalFarms),
            (l10n.ordersAdminChartCrops, metrics.totalCrops),
            (l10n.ordersAdminIssuesReported, metrics.issuesReported),
            (l10n.ordersAdminIssuesPending, metrics.issuesPending),
            (l10n.ordersAdminIssuesResolved, metrics.issuesResolved),
          ],
        ),
      ],
    );
  }
}

/// A few horizontal bars, drawn with plain widgets so the app needs no chart package. Every bar
/// has its label and number written next to it, so it never depends on colour or length alone.
class _TotalsChart extends ConsumerWidget {
  const _TotalsChart({required this.title, required this.bars});

  final String title;
  final List<(String label, int value)> bars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    final largest = bars.fold<int>(0, (max, bar) => bar.$2 > max ? bar.$2 : max);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: Gaps.md),
            for (final (label, value) in bars)
              Padding(
                padding: const EdgeInsets.only(bottom: Gaps.md),
                child: Semantics(
                  label: '$label: ${format.number(value)}',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(label, style: textTheme.bodySmall)),
                          Text(format.number(value), style: textTheme.bodySmall!.mono),
                        ],
                      ),
                      const SizedBox(height: Gaps.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          // A bar for nothing stays empty rather than showing a sliver.
                          value: largest == 0 ? 0 : value / largest,
                          minHeight: 10,
                          color: colors.forest,
                          backgroundColor: colors.tint(colors.forest),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
