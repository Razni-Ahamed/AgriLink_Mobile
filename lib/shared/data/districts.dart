import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

/// Sri Lanka's 25 districts from `GET /api/districts` (no sign-in needed). Loaded once and
/// kept; `ref.invalidate(districtsProvider)` retries after a failure.
final districtsProvider = FutureProvider<List<String>>((ref) {
  return ref
      .watch(apiClientProvider)
      .get('/api/districts', decode: (data) => [for (final item in data! as List) '$item']);
});
