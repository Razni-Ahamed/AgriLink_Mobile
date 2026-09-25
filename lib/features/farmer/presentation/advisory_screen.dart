import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../core/api/api_exception.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/state_views.dart';
import '../../issues/application/advisories.dart';
import '../../issues/data/advisory.dart';
import '../../issues/data/issue_enums.dart';
import '../../issues/presentation/widgets/advisory_view.dart';

/// The advice for one of the farmer's issues.
///
/// While an officer hasn't released it (a draft) the API answers 404 to the farmer, and this
/// says the issue is still being reviewed instead of showing an error. Preliminary advice, from
/// a confident photo diagnosis, is shown clearly labelled as not yet confirmed.
///
/// Phase 4's officer screens can share this path, `/advisories/:advisoryId`, by choosing the screen
/// from the signed-in role in the route file.
class AdvisoryScreen extends ConsumerWidget {
  const AdvisoryScreen({super.key, required this.advisoryId});

  final int advisoryId;

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      ref.invalidate(advisoryProvider(advisoryId));
      await ref.read(advisoryProvider(advisoryId).future);
    } on Object catch (error) {
      // "Not released yet" is an answer, not a failure: the page already says so.
      if (context.mounted && !_isNotReleased(error)) {
        showToast(context, describeError(error, context.l10n), tone: ToastTone.error);
      }
    }
  }

  static bool _isNotReleased(Object error) =>
      error is ApiException && error.kind == ApiErrorKind.notFound;

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
              child: _Content(advisory: advisory!),
            )
          : async.hasError && _isNotReleased(async.error!)
          ? RefreshIndicator(
              onRefresh: () => _refresh(context, ref),
              child: EmptyView(
                icon: Icons.hourglass_top_outlined,
                title: l10n.issuesAdvisoryUnavailable,
                action: OutlinedButton(
                  onPressed: () => context.go(AppRoutes.myIssues),
                  child: Text(l10n.issuesAdvisoryBackToMyIssues),
                ),
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
  const _Content({required this.advisory});

  final Advisory advisory;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        if (advisory.status == AdvisoryStatus.approved) ...[
          InfoBanner(success: true, message: l10n.issuesAdvisoryReady),
          const SizedBox(height: Gaps.md),
        ],
        Text(l10n.issuesAdvisoryNumber(advisory.id), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Gaps.sm),
        AdvisoryView(advisory: advisory, audience: AdvisoryAudience.farmer),
      ],
    );
  }
}
