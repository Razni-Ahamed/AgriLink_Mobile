import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/approvals_api.dart';

/// The applications waiting for the signed-in officer or admin. Cleared on sign-out.
final pendingRegistrationsProvider = FutureProvider.autoDispose<List<PendingRegistration>>((ref) {
  ref.watch(sessionTokenProvider);
  return ref.watch(approvalsApiProvider).pendingRegistrations();
});
