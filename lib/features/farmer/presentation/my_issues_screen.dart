import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../../shared/widgets/state_views.dart';
import '../../issues/data/crop_issue.dart';
import '../../issues/data/issues_api.dart';
import '../application/my_issues.dart';
import '../farmer_paths.dart';
import 'widgets/issue_card.dart';

/// The farmer's reported issues, newest first: an infinitely scrolling list that reloads on
/// pull-down. There are no push notifications yet, so pulling down is how a farmer checks
/// whether an officer has looked at their issue.
class MyIssuesScreen extends ConsumerStatefulWidget {
  const MyIssuesScreen({super.key});

  @override
  ConsumerState<MyIssuesScreen> createState() => _MyIssuesScreenState();
}

class _MyIssuesScreenState extends ConsumerState<MyIssuesScreen> {
  late final PagedListController<CropIssue> _issues = PagedListController(
    loadPage: (page) => ref.read(issuesApiProvider).mine(page: page),
  );

  @override
  void initState() {
    super.initState();
    // A new issue elsewhere in the app means this list is out of date.
    ref.listenManual(issuesRevisionProvider, (_, _) => _issues.refresh());
  }

  @override
  void dispose() {
    _issues.dispose();
    super.dispose();
  }

  void _report() => context.go(FarmerPaths.newIssue());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.issuesMineTitle),
      // Not on an empty list, which already has its own "Report an Issue" button.
      floatingActionButton: ListenableBuilder(
        listenable: _issues,
        builder: (context, _) => _issues.items.isEmpty
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                key: const Key('report-issue'),
                onPressed: _report,
                icon: const Icon(Icons.add),
                label: Text(l10n.issuesMineReportIssue),
              ),
      ),
      body: PagedListView<CropIssue>(
        controller: _issues,
        // Room under the last card for the floating button.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        empty: EmptyView(
          icon: Icons.healing_outlined,
          title: l10n.issuesMineEmpty,
          message: l10n.issuesMineEmptyHint,
          action: FilledButton.icon(
            onPressed: _report,
            icon: const Icon(Icons.add),
            label: Text(l10n.issuesMineReportIssue),
          ),
        ),
        itemBuilder: (context, issue, _) => IssueCard(
          key: Key('issue-${issue.id}'),
          issue: issue,
          onTap: () => context.go(FarmerPaths.issue(issue.id), extra: issue),
        ),
      ),
    );
  }
}
