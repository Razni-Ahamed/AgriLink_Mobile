import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/officer_api.dart';

/// The signed-in officer's dashboard numbers. Cleared on sign-out.
final officerMetricsProvider = FutureProvider.autoDispose<OfficerMetrics>((ref) {
  ref.watch(sessionTokenProvider);
  return ref.watch(officerApiProvider).metrics();
});
