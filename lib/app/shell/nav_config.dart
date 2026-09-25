import 'package:flutter/material.dart';

import '../../core/session/role.dart';
import '../../l10n/l10n.dart';
import '../router/app_routes.dart';

/// One section of the app: its path, its name, its icon and who may open it. The same
/// `allowedRoles` as the website's `features/*/routes.tsx`.
class NavDestination {
  const NavDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.roles,
    this.shortLabel,
  });

  final String path;

  /// The page title and the name in the "More" list.
  final String Function(AppLocalizations l10n) label;

  /// A shorter name for the bottom bar, where space is tight. Defaults to [label].
  final String Function(AppLocalizations l10n)? shortLabel;
  final IconData icon;
  final IconData selectedIcon;
  final Set<Role> roles;

  String tabLabel(AppLocalizations l10n) => (shortLabel ?? label)(l10n);

  /// Whether [location] is this section or a page inside it (`/farms/12` is in Farms).
  bool contains(String location) => location == path || location.startsWith('$path/');
}

const _allRoles = {Role.farmer, Role.buyer, Role.officer, Role.admin};

/// Every section. Phases 2–4 build the screens behind these; the list itself only changes if
/// a section is added or moved.
abstract final class Destinations {
  // Phase 2: farmer.
  static final farms = NavDestination(
    path: AppRoutes.farms,
    label: (l) => l.commonNavFarms,
    icon: Icons.agriculture_outlined,
    selectedIcon: Icons.agriculture,
    roles: {Role.farmer},
  );
  static final myIssues = NavDestination(
    path: AppRoutes.myIssues,
    label: (l) => l.commonNavMyIssues,
    icon: Icons.healing_outlined,
    selectedIcon: Icons.healing,
    roles: {Role.farmer},
  );

  // Phase 3: marketplace and orders.
  static final marketplace = NavDestination(
    path: AppRoutes.marketplace,
    label: (l) => l.commonNavMarketplace,
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront,
    roles: {Role.farmer, Role.buyer, Role.admin},
  );
  static final myListings = NavDestination(
    path: AppRoutes.myListings,
    label: (l) => l.commonNavMyListings,
    icon: Icons.shopping_basket_outlined,
    selectedIcon: Icons.shopping_basket,
    roles: {Role.farmer},
  );

  /// Purchase requests buyers sent to this farmer.
  static final incomingRequests = NavDestination(
    path: AppRoutes.incomingRequests,
    label: (l) => l.commonNavMyRequests,
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment,
    roles: {Role.farmer},
  );

  /// Purchase requests this buyer sent.
  static final sentRequests = NavDestination(
    path: AppRoutes.sentRequests,
    label: (l) => l.commonNavMyRequests,
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment,
    roles: {Role.buyer},
  );
  static final orders = NavDestination(
    path: AppRoutes.orders,
    label: (l) => l.commonNavOrders,
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
    roles: {Role.farmer, Role.buyer},
  );

  // Phase 4: officer and admin.
  static final officerDashboard = NavDestination(
    path: AppRoutes.officerDashboard,
    label: (l) => l.commonNavOfficerDashboard,
    icon: Icons.speed_outlined,
    selectedIcon: Icons.speed,
    roles: {Role.officer},
  );
  static final pendingIssues = NavDestination(
    path: AppRoutes.pendingIssues,
    label: (l) => l.commonNavPendingIssues,
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist,
    roles: {Role.officer, Role.admin},
  );
  static final reviewedIssues = NavDestination(
    path: AppRoutes.reviewedIssues,
    label: (l) => l.commonNavMyReviews,
    icon: Icons.history_outlined,
    selectedIcon: Icons.history,
    roles: {Role.officer},
  );
  static final approvals = NavDestination(
    path: AppRoutes.approvals,
    label: (l) => l.commonNavPendingRegistrations,
    icon: Icons.how_to_reg_outlined,
    selectedIcon: Icons.how_to_reg,
    roles: {Role.officer, Role.admin},
  );
  static final adminDashboard = NavDestination(
    path: AppRoutes.adminDashboard,
    label: (l) => l.commonNavAdminDashboard,
    shortLabel: (l) => l.commonNavOfficerDashboard,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    roles: {Role.admin},
  );
  static final allIssues = NavDestination(
    path: AppRoutes.allIssues,
    label: (l) => l.commonNavAllIssues,
    icon: Icons.table_chart_outlined,
    selectedIcon: Icons.table_chart,
    roles: {Role.admin},
  );
  static final users = NavDestination(
    path: AppRoutes.adminUsers,
    label: (l) => l.commonNavManageUsers,
    icon: Icons.group_outlined,
    selectedIcon: Icons.group,
    roles: {Role.admin},
  );
  static final departments = NavDestination(
    path: AppRoutes.adminDepartments,
    label: (l) => l.commonNavDepartments,
    icon: Icons.apartment_outlined,
    selectedIcon: Icons.apartment,
    roles: {Role.admin},
  );
  static final auditLog = NavDestination(
    path: AppRoutes.adminAuditLog,
    label: (l) => l.commonNavAuditLog,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    roles: {Role.admin},
  );

  // Everyone.
  static final notifications = NavDestination(
    path: AppRoutes.notifications,
    label: (l) => l.commonNavNotifications,
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    roles: _allRoles,
  );
  static final profile = NavDestination(
    path: AppRoutes.profile,
    label: (l) => l.commonNavProfile,
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    roles: _allRoles,
  );
  static final more = NavDestination(
    path: AppRoutes.more,
    label: (l) => l.commonNavMore,
    icon: Icons.more_horiz,
    selectedIcon: Icons.more_horiz,
    roles: _allRoles,
  );
}

/// A role's sections: the ones on the bottom bar, and the rest under "More".
class RoleNavigation {
  const RoleNavigation({required this.tabs, this.overflow = const []});

  final List<NavDestination> tabs;
  final List<NavDestination> overflow;

  bool get hasMore => overflow.isNotEmpty;

  List<NavDestination> get all => [...tabs, ...overflow];
}

/// At most four tabs plus "More", so labels stay readable in Sinhala and Tamil on a narrow
/// phone. The most used sections are the tabs; the rest are one tap away under "More".
RoleNavigation navigationFor(Role role) => switch (role) {
  Role.farmer => RoleNavigation(
    tabs: [
      Destinations.farms,
      Destinations.myIssues,
      Destinations.marketplace,
      Destinations.orders,
    ],
    overflow: [Destinations.myListings, Destinations.incomingRequests],
  ),
  Role.buyer => RoleNavigation(
    tabs: [Destinations.marketplace, Destinations.sentRequests, Destinations.orders],
  ),
  Role.officer => RoleNavigation(
    tabs: [
      Destinations.officerDashboard,
      Destinations.pendingIssues,
      Destinations.reviewedIssues,
      Destinations.approvals,
    ],
  ),
  Role.admin => RoleNavigation(
    tabs: [
      Destinations.adminDashboard,
      Destinations.pendingIssues,
      Destinations.approvals,
      Destinations.users,
    ],
    overflow: [
      Destinations.allIssues,
      Destinations.marketplace,
      Destinations.departments,
      Destinations.auditLog,
    ],
  ),
};
