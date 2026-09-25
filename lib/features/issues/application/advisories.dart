import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/advisory.dart';
import '../data/issues_api.dart';

/// One advisory by id. Cleared on sign-out, so the next person on the phone never sees it.
///
/// For a farmer, a draft advisory isn't released and the API answers 404; the screen treats that
/// as "still being reviewed" rather than as an error.
final advisoryProvider = FutureProvider.autoDispose.family<Advisory, int>((ref, id) {
  ref.watch(sessionTokenProvider);
  return ref.watch(issuesApiProvider).advisory(id);
});
