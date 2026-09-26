import '../../../core/session/role.dart';
import '../data/admin_models.dart';

/// Which accounts to show by whether they can sign in.
enum UserStatusFilter { all, active, inactive }

/// The users list is one plain (not paged) response, so search and filters run on the device.
///
/// [query] matches part of the name, email or username, ignoring case and surrounding spaces.
/// A [role] of null and a [status] of [UserStatusFilter.all] don't narrow anything.
List<AdminUser> filterUsers(
  List<AdminUser> users, {
  String query = '',
  Role? role,
  UserStatusFilter status = UserStatusFilter.all,
}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final user in users)
      if ((role == null || user.role == role) &&
          switch (status) {
            UserStatusFilter.all => true,
            UserStatusFilter.active => user.isActive,
            UserStatusFilter.inactive => !user.isActive,
          } &&
          (needle.isEmpty ||
              user.fullName.toLowerCase().contains(needle) ||
              user.email.toLowerCase().contains(needle) ||
              user.username.toLowerCase().contains(needle)))
        user,
  ];
}
