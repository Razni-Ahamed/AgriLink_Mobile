import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../issues/data/crop_issue.dart';
import '../../issues/data/issues_api.dart';

/// Goes up each time the farmer's issues change (a new one is reported), so the "My Issues" list,
/// which keeps its own pages, knows to start again from page 1.
class IssuesRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final issuesRevisionProvider = NotifierProvider<IssuesRevision, int>(IssuesRevision.new);

/// One of the farmer's issues, or null if they have none with this id. The API has no "issue by
/// id", so this pages through their issues until it finds it. It is only used when a page is
/// opened without the issue in hand (a saved link); from the list the issue is passed along.
final myIssueProvider = FutureProvider.autoDispose.family<CropIssue?, int>((ref, issueId) async {
  ref
    ..watch(sessionTokenProvider)
    ..watch(issuesRevisionProvider);
  final api = ref.watch(issuesApiProvider);
  var page = 1;
  while (true) {
    final result = await api.mine(page: page, pageSize: 50);
    for (final issue in result.items) {
      if (issue.id == issueId) {
        return issue;
      }
    }
    if (!result.hasMore) {
      return null;
    }
    page++;
  }
});
