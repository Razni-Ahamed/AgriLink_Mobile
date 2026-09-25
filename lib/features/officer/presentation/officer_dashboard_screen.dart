import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/format/formatters.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/officer_metrics.dart';
import '../data/officer_api.dart';

/// The officer's home: their district and department, and the numbers for their queue and
/// their own reviews. Pull down to refresh.
class OfficerDashboardScreen extends ConsumerWidget {
  const OfficerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final metrics = ref.watch(officerMetricsProvider);
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.officerDashboardTitle),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(officerMetricsProvider);
          try {
            await ref.read(officerMetricsProvider.future);
          } on Object {
            // The screen shows the error itself; the spinner only has to stop.
          }
        },
        child: AsyncValueView(
          value: metrics,
          onRetry: () => ref.invalidate(officerMetricsProvider),
          data: (data) => _Dashboard(metrics: data),
        ),
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.metrics});

  final OfficerMetrics metrics;

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
        Wrap(
          spacing: Gaps.sm,
          runSpacing: Gaps.sm,
          children: [
            if (metrics.district.isNotEmpty)
              _Chip(icon: Icons.place_outlined, label: metrics.district),
            if (metrics.departmentName.isNotEmpty)
              _Chip(icon: Icons.apartment_outlined, label: metrics.departmentName),
          ],
        ),
        const SizedBox(height: Gaps.md),
        _Grid(
          children: [
            MetricCard(
              key: const Key('metric-pending'),
              label: l10n.officerDashboardPendingInDistrict,
              value: n(metrics.pendingInDistrict),
              icon: Icons.warning_amber_outlined,
              tone: MetricTone.harvest,
              onTap: () => open(AppRoutes.pendingIssues),
            ),
            MetricCard(
              label: l10n.officerDashboardReviewedToday,
              value: n(metrics.reviewedToday),
              icon: Icons.check_circle_outline,
            ),
            MetricCard(
              label: l10n.officerDashboardReviewedTotal,
              value: n(metrics.reviewedTotal),
              icon: Icons.fact_check_outlined,
              onTap: () => open(AppRoutes.reviewedIssues),
            ),
            MetricCard(
              label: l10n.officerDashboardApprovedTotal,
              value: n(metrics.approvedTotal),
              icon: Icons.thumb_up_alt_outlined,
              onTap: () => open(AppRoutes.reviewedIssues),
            ),
            MetricCard(
              label: l10n.officerDashboardRejectedTotal,
              value: n(metrics.rejectedTotal),
              icon: Icons.cancel_outlined,
              tone: MetricTone.terracotta,
              onTap: () => open(AppRoutes.reviewedIssues),
            ),
          ],
        ),
        const SizedBox(height: Gaps.md),
        _LinkCard(
          key: const Key('go-to-queue'),
          icon: Icons.checklist_outlined,
          title: l10n.officerDashboardGoToQueue,
          hint: l10n.officerDashboardGoToQueueHint,
          onTap: () => open(AppRoutes.pendingIssues),
        ),
        const SizedBox(height: Gaps.sm),
        _LinkCard(
          key: const Key('go-to-reviews'),
          icon: Icons.history_outlined,
          title: l10n.officerDashboardGoToReviews,
          hint: l10n.officerDashboardGoToReviewsHint,
          onTap: () => open(AppRoutes.reviewedIssues),
        ),
      ],
    );
  }
}

/// Two cards to a row on a phone. A row is as tall as its taller card, so long Sinhala and Tamil
/// labels never overflow.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

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

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.sm + 4, vertical: Gaps.xs + 2),
      decoration: BoxDecoration(
        color: colors.tint(colors.forest),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.forest),
          const SizedBox(width: Gaps.xs),
          Flexible(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: Row(
            children: [
              Icon(icon, color: context.colors.forest),
              const SizedBox(width: Gaps.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
