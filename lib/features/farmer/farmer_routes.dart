import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_guard.dart';
import '../../app/shell/nav_config.dart';
import '../../app/shell/not_found_screen.dart';
import '../../app/shell/placeholder_page.dart';
import 'presentation/crop_detail_screen.dart';
import 'presentation/farm_detail_screen.dart';
import 'presentation/farms_screen.dart';
import 'presentation/field_detail_screen.dart';

/// Phase 2 (farmer): farms, fields, crops, reporting crop issues and advisories.
///
/// The farm pages match the website's paths: `/farms/:farmId`, `/farms/:farmId/fields/:fieldId`
/// and `/farms/:farmId/fields/:fieldId/crops/:cropId`. All are farmer-only, because they sit
/// under the guarded `/farms` route. "My Issues" is still a placeholder.
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
    builder: (context, state) => PlaceholderPage(destination: Destinations.myIssues),
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
