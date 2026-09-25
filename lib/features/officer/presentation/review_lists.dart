import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/paged.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../../shared/widgets/state_views.dart';
import '../../issues/data/crop_issue.dart';
import '../data/review_api.dart';
import 'widgets/review_issue_card.dart';
import 'widgets/scope_note.dart';

/// Issues waiting for a decision. An officer only receives their own district's (the server
/// scopes it); an admin sees every district. Opening one goes to the review screen, and a
/// decision there reloads this list.
class PendingIssuesScreen extends StatelessWidget {
  const PendingIssuesScreen({super.key});

  @override
  Widget build(BuildContext context) => _IssuesList(
    kind: ReviewListKind.pending,
    basePath: AppRoutes.pendingIssues,
    title: context.l10n.issuesPendingTitle,
    empty: context.l10n.issuesPendingEmpty,
    load: (api, page) => api.pending(page: page),
  );
}

/// The issues this officer has already decided, most recent first. They open read-only.
class ReviewedIssuesScreen extends StatelessWidget {
  const ReviewedIssuesScreen({super.key});

  @override
  Widget build(BuildContext context) => _IssuesList(
    kind: ReviewListKind.reviewed,
    basePath: AppRoutes.reviewedIssues,
    title: context.l10n.issuesReviewedTitle,
    subtitle: context.l10n.issuesReviewedSubtitle,
    empty: context.l10n.issuesReviewedEmpty,
    load: (api, page) => api.reviewed(page: page),
  );
}

/// Every issue, whatever its status (admin). Awaiting ones can still be decided from here.
class AllIssuesScreen extends StatelessWidget {
  const AllIssuesScreen({super.key});

  @override
  Widget build(BuildContext context) => _IssuesList(
    kind: ReviewListKind.all,
    basePath: AppRoutes.allIssues,
    title: context.l10n.issuesAllTitle,
    subtitle: context.l10n.issuesAllSubtitle,
    empty: context.l10n.issuesAllEmpty,
    load: (api, page) => api.all(page: page),
  );
}

class _IssuesList extends ConsumerStatefulWidget {
  const _IssuesList({
    required this.kind,
    required this.basePath,
    required this.title,
    required this.empty,
    required this.load,
    this.subtitle,
  });

  final ReviewListKind kind;

  /// The list's own path; an advisory opens at `<basePath>/<advisoryId>`.
  final String basePath;
  final String title;
  final String? subtitle;
  final String empty;
  final Future<Paged<CropIssue>> Function(ReviewApi api, int page) load;

  @override
  ConsumerState<_IssuesList> createState() => _IssuesListState();
}

class _IssuesListState extends ConsumerState<_IssuesList> {
  late final PagedListController<CropIssue> _issues = PagedListController(
    loadPage: (page) => widget.load(ref.read(reviewApiProvider), page),
  );

  @override
  void dispose() {
    _issues.dispose();
    super.dispose();
  }

  /// Opens the advisory. The review screen answers `true` when a decision was made, and then
  /// this list is out of date.
  Future<void> _open(CropIssue issue) async {
    final decided = await context.push<bool>('${widget.basePath}/${issue.advisoryId}');
    if (decided == true) {
      await _issues.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = widget.subtitle;
    return Scaffold(
      appBar: AgriLinkAppBar(title: widget.title),
      body: Column(
        children: [
          if (widget.kind == ReviewListKind.pending)
            ScopeNote(forOfficer: l10n.issuesPendingScopedToDistrict),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          Expanded(
            child: PagedListView<CropIssue>(
              controller: _issues,
              empty: EmptyView(title: widget.empty),
              itemBuilder: (context, issue, _) => ReviewIssueCard(
                key: ValueKey(issue.id),
                issue: issue,
                kind: widget.kind,
                // An issue with no advisory yet has nothing to open.
                onTap: issue.advisoryId == null ? null : () => _open(issue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
