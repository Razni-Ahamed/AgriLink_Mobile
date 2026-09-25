import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/account_api.dart';
import '../data/account_models.dart';

/// `GET /api/users/me/security`: what the user may change, their phone and NIC, and their own
/// change requests. Reloaded after every change on the security screen.
final securitySettingsProvider = FutureProvider.autoDispose<SecuritySettings>((ref) {
  ref.watch(sessionTokenProvider);
  return ref.watch(accountApiProvider).security();
});
