import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/state_views.dart';
import '../../issues/application/advisories.dart';
import '../../issues/data/advisory.dart';
import '../../issues/presentation/widgets/advisory_view.dart';
import '../application/officer_metrics.dart';
import '../application/review_rules.dart';
import '../data/review_api.dart';
import 'widgets/agent_trace_panel.dart';
import 'widgets/photo_diagnosis_panel.dart';
import 'widgets/previous_issues_panel.dart';
import 'widgets/review_controls.dart';

/// One advisory, for an officer or admin: everything the farmer would see (Phase 2's
/// `AdvisoryView`, with photos and full-screen zoom), then what only a reviewer gets (the photo
/// diagnosis details, the crop's previous issues and how the AI reached its advice), then either
/// the decision controls or, once it has been decided, a note that it is read-only.
///
/// On a decision the screen goes back to the list, answering `true` so the list reloads. If
/// someone else decided first, it says so and shows the advisory as it now stands.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key, required this.advisoryId, required this.listPath});

  final int advisoryId;

  /// Where to go if there is nothing to go back to (the page was opened directly).
  final String listPath;

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      ref.invalidate(advisoryProvider(advisoryId));
      await ref.read(advisoryProvider(advisoryId).future);
    } on Object catch (error) {
      if (context.mounted) {
        showToast(context, describeError(error, context.l10n), tone: ToastTone.error);
      }
    }
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    Advisory advisory,
    ReviewAction action,
    ReviewAdvisoryRequest request,
  ) async {
    final l10n = context.l10n;
    final api = ref.read(reviewApiProvider);
    final photo = advisory.photoDiagnosis != null;
    try {
      if (action == ReviewAction.approve) {
        await api.approve(advisory.id, request);
      } else {
        await api.reject(advisory.id, request);
      }
    } on Object catch (error) {
      // Someone else may have decided it already. Load it again: if it can no longer be
      // reviewed, say so (the screen now shows the decision); otherwise show what went wrong.
      Advisory? fresh;
      try {
        ref.invalidate(advisoryProvider(advisory.id));
        fresh = await ref.read(advisoryProvider(advisory.id).future);
      } on Object {
        fresh = null;
      }
      if (context.mounted) {
        showToast(
          context,
          fresh != null && !canReview(fresh)
              ? l10n.officerReviewAlreadyReviewed
              : describeError(error, l10n),
          tone: ToastTone.error,
        );
      }
      // The controls keep what was typed.
      rethrow;
    }
    ref.invalidate(advisoryProvider(advisory.id));
    ref.invalidate(officerMetricsProvider);
    if (!context.mounted) {
      return;
    }
    showToast(context, switch ((action, photo)) {
      (ReviewAction.approve, true) => l10n.issuesAdvisoryReviewConfirmed,
      (ReviewAction.approve, false) => l10n.issuesAdvisoryApproved,
      (ReviewAction.reject, true) => l10n.issuesAdvisoryReviewCorrected,
      (ReviewAction.reject, false) => l10n.issuesAdvisoryRejected,
    }, tone: ToastTone.success);
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go(listPath);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(advisoryProvider(advisoryId));
    final advisory = async.value;
    return Scaffold(
      appBar: AgriLinkAppBar(title: advisory?.issueTitle ?? l10n.issuesAdvisoryNumber(advisoryId)),
      body: async.hasValue
          ? RefreshIndicator(
              onRefresh: () => _refresh(context, ref),
              child: _Content(
                advisory: advisory!,
                onDecide: (action, request) => _decide(context, ref, advisory, action, request),
              ),
            )
          : async.hasError
          ? ErrorView(
              error: async.error!,
              onRetry: () => ref.invalidate(advisoryProvider(advisoryId)),
            )
          : const LoadingView(),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.advisory, required this.onDecide});

  final Advisory advisory;
  final Future<void> Function(ReviewAction action, ReviewAdvisoryRequest request) onDecide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final previous = advisory.previousIssues;
    final trace = advisory.agentTrace;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        AdvisoryView(advisory: advisory),
        if (advisory.photoDiagnosis != null) ...[
          const SizedBox(height: Gaps.md),
          PhotoDiagnosisPanel(advisory: advisory),
        ],
        if (previous != null) ...[
          const SizedBox(height: Gaps.md),
          PreviousIssuesPanel(
            issues: previous,
            // A previous issue's advisory opens like any other, with the same decision controls
            // if it is still waiting.
            onOpen: (id) => context.push('${AppRoutes.pendingIssues}/$id'),
          ),
        ],
        if (trace != null && trace.steps.isNotEmpty) ...[
          const SizedBox(height: Gaps.md),
          AgentTracePanel(trace: trace),
        ],
        const SizedBox(height: Gaps.lg),
        if (canReview(advisory))
          // Keyed by the advisory, so a reload after a pull-down keeps what was typed.
          ReviewControls(key: ValueKey(advisory.id), advisory: advisory, onSubmit: onDecide)
        else
          InfoBanner(message: l10n.officerReviewReadOnly),
      ],
    );
  }
}
