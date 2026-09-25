import 'dart:typed_data';

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

/// The bytes of one issue photo, by its API path. Photos never change once stored, and the API
/// lets the browser cache them for a day; here the bytes live as long as a screen shows them.
final issuePhotoProvider = FutureProvider.autoDispose.family<Uint8List, String>((ref, url) {
  ref.watch(sessionTokenProvider);
  return ref.watch(issuesApiProvider).photoBytes(url);
});
