import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../app/shell/nav_config.dart';
import '../../app/shell/not_found_screen.dart';
import 'presentation/approvals_screen.dart';
import 'presentation/officer_dashboard_screen.dart';
import 'presentation/review_lists.dart';
import 'presentation/review_screen.dart';

/// Phase 4 (officer): the dashboard, issue reviews and registration approvals. The pending
/// issues and approvals pages are shared with admins.
///
/// An advisory opens under the list it came from: `/issues/pending/:advisoryId`,
/// `/issues/reviewed/:advisoryId`. The child route takes its roles from the list, so the review
/// screen is available to whoever may open that list. (`/issues/all/:advisoryId` is the admin's,
/// in `admin_routes.dart`.)
List<RouteBase> officerRoutes(RouteGuard guard) => [
  guard.route(
    path: Destinations.officerDashboard.path,
    roles: Destinations.officerDashboard.roles,
    builder: (context, state) => const OfficerDashboardScreen(),
  ),
  guard.route(
    path: Destinations.approvals.path,
    roles: Destinations.approvals.roles,
    builder: (context, state) => const ApprovalsScreen(),
  ),
  guard.route(
    path: Destinations.pendingIssues.path,
    roles: Destinations.pendingIssues.roles,
    builder: (context, state) => const PendingIssuesScreen(),
    routes: [reviewRoute(Destinations.pendingIssues.path)],
  ),
  guard.route(
    path: Destinations.reviewedIssues.path,
    roles: Destinations.reviewedIssues.roles,
    builder: (context, state) => const ReviewedIssuesScreen(),
    routes: [reviewRoute(Destinations.reviewedIssues.path)],
  ),
];

/// The review screen for `<list>/:advisoryId`, or the not-found page if the id isn't a number.
GoRoute reviewRoute(String listPath) => GoRoute(
  path: ':advisoryId',
  builder: (context, state) {
    final id = int.tryParse(state.pathParameters['advisoryId'] ?? '');
    return id == null ? const NotFoundScreen() : ReviewScreen(advisoryId: id, listPath: listPath);
  },
);
