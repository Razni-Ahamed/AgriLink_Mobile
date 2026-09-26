import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../app/shell/nav_config.dart';
import '../../app/shell/not_found_screen.dart';
import '../../core/session/role.dart';
import '../issues/data/crop_issue.dart';
import 'farmer_paths.dart';
import 'presentation/advisory_screen.dart';
import 'presentation/crop_detail_screen.dart';
import 'presentation/farm_detail_screen.dart';
import 'presentation/farms_screen.dart';
import 'presentation/field_detail_screen.dart';
import 'presentation/issue_detail_screen.dart';
import 'presentation/my_issues_screen.dart';
import 'presentation/report_issue_screen.dart';

/// Phase 2 (farmer): farms, fields, crops, reporting crop issues and advisories.
///
/// The farm pages match the website's paths: `/farms/:farmId`, `/farms/:farmId/fields/:fieldId`
/// and `/farms/:farmId/fields/:fieldId/crops/:cropId`. The issue pages sit under "My Issues":
/// `/issues/mine/new` (optionally `?cropId=`) and `/issues/mine/:issueId`. The advice is at the
/// website's `/advisories/:advisoryId`. All are farmer-only.
///
/// Phase 4 (officer and admin) also needs `/advisories/:advisoryId`: add its roles here and pick
/// the screen from the signed-in role in the builder, so the path is registered once.
List<RouteBase> farmerRoutes(RouteGuard guard) => [
  guard.route(
    path: Destinations.farms.path,
    roles: Destinations.farms.roles,
    builder: (context, state) => const FarmsScreen(),
    routes: [
      GoRoute(
        path: ':farmId',
        builder: (context, state) =>
            _withIds(state, ['farmId'], (ids) => FarmDetailScreen(farmId: ids[0])),
        routes: [
          GoRoute(
            path: 'fields/:fieldId',
            builder: (context, state) => _withIds(state, [
              'farmId',
              'fieldId',
            ], (ids) => FieldDetailScreen(farmId: ids[0], fieldId: ids[1])),
            routes: [
              GoRoute(
                path: 'crops/:cropId',
                builder: (context, state) => _withIds(state, [
                  'fieldId',
                  'cropId',
                ], (ids) => CropDetailScreen(fieldId: ids[0], cropId: ids[1])),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  guard.route(
    path: Destinations.myIssues.path,
    roles: Destinations.myIssues.roles,
    builder: (context, state) => const MyIssuesScreen(),
    routes: [
      // Before ':issueId', so "new" isn't read as an issue.
      GoRoute(
        path: 'new',
        builder: (context, state) => ReportIssueScreen(
          initialCropId: int.tryParse(state.uri.queryParameters['cropId'] ?? ''),
        ),
      ),
      GoRoute(
        path: ':issueId',
        builder: (context, state) {
          final extra = state.extra;
          return _withIds(
            state,
            ['issueId'],
            (ids) => IssueDetailScreen(
              issueId: ids[0],
              initial: extra is CropIssue && extra.id == ids[0] ? extra : null,
            ),
          );
        },
      ),
    ],
  ),
  guard.route(
    path: FarmerPaths.advisoryPattern,
    roles: {Role.farmer},
    builder: (context, state) =>
        _withIds(state, ['advisoryId'], (ids) => AdvisoryScreen(advisoryId: ids[0])),
  ),
];

/// Builds a page from the numbers in the link, or the not-found page if one isn't a number
/// (`/farms/abc`).
Widget _withIds(GoRouterState state, List<String> names, Widget Function(List<int> ids) build) {
  final ids = [for (final name in names) int.tryParse(state.pathParameters[name] ?? '')];
  if (ids.contains(null)) {
    return const NotFoundScreen();
  }
  return build(ids.cast<int>());
}
