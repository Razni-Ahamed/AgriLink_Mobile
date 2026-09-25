import '../../core/session/role.dart';

/// Every path in the app. They match the website's paths, so a link means the same thing on
/// both. Feature screens from phases 2–4 replace the placeholders registered for these paths.
abstract final class AppRoutes {
  // Signed out.
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const registerPending = '/register/pending';

  // Everyone signed in.
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const profileSecurity = '/profile/security';
  static const more = '/more';

  // Farmer (phase 2) and marketplace (phase 3).
  static const farms = '/farms';
  static const myIssues = '/issues/mine';
  static const marketplace = '/marketplace/browse';
  static const myListings = '/marketplace/mine';
  static const incomingRequests = '/marketplace/requests';
  static const sentRequests = '/marketplace/sent-requests';
  static const orders = '/orders/mine';

  // Officer and admin (phase 4).
  static const officerDashboard = '/officer/dashboard';
  static const pendingIssues = '/issues/pending';
  static const reviewedIssues = '/issues/reviewed';
  static const allIssues = '/issues/all';
  static const approvals = '/registrations/pending';
  static const adminDashboard = '/admin';
  static const adminUsers = '/admin/users';
  static const adminDepartments = '/admin/departments';
  static const adminAuditLog = '/admin/audit-log';

  /// Screens anyone may see without signing in.
  static const signedOut = {splash, login, register, registerPending};
}

/// Where each role lands after signing in (the website's roleHome.ts).
String homePathFor(Role role) => switch (role) {
  Role.farmer => AppRoutes.farms,
  Role.buyer => AppRoutes.marketplace,
  Role.officer => AppRoutes.officerDashboard,
  Role.admin => AppRoutes.adminDashboard,
};
