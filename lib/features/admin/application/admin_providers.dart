import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/admin_api.dart';
import '../data/admin_models.dart';

// Every provider here watches the session, so nothing an admin loaded is still there for the next
// person who signs in on the same phone.

final adminMetricsProvider = FutureProvider.autoDispose<AdminMetrics>((ref) {
  ref.watch(sessionTokenProvider);
  return ref.watch(adminApiProvider).metrics();
});

/// Every user. The users screen and a user's detail page both read this one list, so an action
/// on the detail page (which reloads it) shows on the list straight away.
final adminUsersProvider = FutureProvider.autoDispose<List<AdminUser>>((ref) {
  ref.watch(sessionTokenProvider);
  return ref.watch(adminApiProvider).users();
});

final departmentsProvider = FutureProvider.autoDispose<List<Department>>((ref) {
  ref.watch(sessionTokenProvider);
  return ref.watch(adminApiProvider).departments();
});
