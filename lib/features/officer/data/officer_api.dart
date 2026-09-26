import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';

/// The officer's own dashboard numbers (`GET /api/officer/metrics`): their district's queue and
/// their own review history.
class OfficerMetrics {
  const OfficerMetrics({
    required this.district,
    required this.departmentName,
    required this.pendingInDistrict,
    required this.reviewedToday,
    required this.reviewedTotal,
    required this.approvedTotal,
    required this.rejectedTotal,
  });

  factory OfficerMetrics.fromJson(Json json) => OfficerMetrics(
    district: json['district'] as String? ?? '',
    departmentName: json['departmentName'] as String? ?? '',
    pendingInDistrict: (json['pendingInDistrict'] as num? ?? 0).toInt(),
    reviewedToday: (json['reviewedToday'] as num? ?? 0).toInt(),
    reviewedTotal: (json['reviewedTotal'] as num? ?? 0).toInt(),
    approvedTotal: (json['approvedTotal'] as num? ?? 0).toInt(),
    rejectedTotal: (json['rejectedTotal'] as num? ?? 0).toInt(),
  );

  final String district;
  final String departmentName;
  final int pendingInDistrict;
  final int reviewedToday;
  final int reviewedTotal;
  final int approvedTotal;
  final int rejectedTotal;
}

/// `/api/officer`: what only officers see.
class OfficerApi {
  OfficerApi(this._api);

  final ApiClient _api;

  Future<OfficerMetrics> metrics() =>
      _api.get('/api/officer/metrics', decode: (data) => OfficerMetrics.fromJson(asJson(data)));
}

final officerApiProvider = Provider<OfficerApi>((ref) => OfficerApi(ref.watch(apiClientProvider)));
