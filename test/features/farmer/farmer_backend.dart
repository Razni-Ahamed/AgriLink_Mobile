import 'dart:async';
import 'dart:typed_data';

import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/core/session/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../issues/issue_fixtures.dart';
import 'farmer_fixtures.dart';

/// A fake API that can hold a report to `/api/issues` open until the test lets it through, to
/// look at the screen while the server is still "analysing".
class GatedApi extends FakeApi {
  Completer<void>? gate;

  /// Answer reports with a timeout, like a server that never replied in time.
  bool timeOutReports = false;

  /// How many reports reached the API, counted before any wait at the gate.
  int reportAttempts = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final isReport = options.method == 'POST' && options.uri.path.startsWith('/api/issues');
    if (isReport) {
      reportAttempts++;
    }
    if (isReport && gate != null) {
      await gate!.future;
    }
    if (isReport && timeOutReports) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 120),
        requestOptions: options,
      );
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

/// A pretend farmer API that remembers what the app does: create a farm and it shows up in the
/// list, delete one and it is gone. Ids are fixed ranges so each path can be registered:
/// farms 1 to 9, fields 10 to 19, crops 100 to 109.
class FarmerBackend {
  FarmerBackend(
    this.api, {
    List<Map<String, Object?>>? farms,
    List<Map<String, Object?>>? fields,
    List<Map<String, Object?>>? crops,
    List<Map<String, Object?>>? issues,
    Map<int, Map<String, Object?>>? advisories,
  }) : farms = farms ?? [farmJson()],
       fields = fields ?? [fieldJson()],
       crops = crops ?? [cropJson()],
       issues = issues ?? [],
       advisories = advisories ?? {} {
    api
      ..on('GET', '/api/users/me', (_) => FakeResponse(200, profileJson(Role.farmer)))
      ..on('GET', '/api/districts', (_) => const FakeResponse(200, ['Kandy', 'Galle', 'Colombo']))
      ..on(
        'GET',
        '/api/crop-types',
        (_) => const FakeResponse(200, ['Paddy', 'Green Gram', 'Tomato']),
      )
      ..on('GET', '/api/farms', (_) => FakeResponse(200, this.farms))
      ..on('POST', '/api/farms', (request) {
        final body = request.json;
        final farm = farmJson(
          id: _nextFarm++,
          name: body['name']! as String,
          district: body['district']! as String,
          area: body['area']! as num,
        );
        this.farms.insert(0, farm);
        return FakeResponse(201, farm);
      });

    for (var id = 1; id <= 9; id++) {
      api
        ..on('PUT', '/api/farms/$id', (request) {
          final body = request.json;
          final index = this.farms.indexWhere((farm) => farm['farmId'] == id);
          this.farms[index] = farmJson(
            id: id,
            name: body['name']! as String,
            district: body['district']! as String,
            area: body['area']! as num,
          );
          return FakeResponse(200, this.farms[index]);
        })
        ..on('DELETE', '/api/farms/$id', (_) {
          this.farms.removeWhere((farm) => farm['farmId'] == id);
          return const FakeResponse(204);
        })
        ..on(
          'GET',
          '/api/farms/$id/fields',
          (_) => FakeResponse(200, [
            for (final field in this.fields)
              if (field['farmId'] == id) field,
          ]),
        )
        ..on('POST', '/api/farms/$id/fields', (request) {
          final body = request.json;
          final field = fieldJson(
            id: _nextField++,
            farmId: id,
            name: body['name']! as String,
            area: body['area']! as num,
          );
          this.fields.add(field);
          return FakeResponse(201, field);
        });
    }

    for (var id = 10; id <= 19; id++) {
      api
        ..on(
          'GET',
          '/api/fields/$id/crops',
          (_) => FakeResponse(200, [
            for (final crop in this.crops)
              if (crop['fieldId'] == id) crop,
          ]),
        )
        ..on('POST', '/api/fields/$id/crops', (request) {
          final body = request.json;
          final crop = cropJson(
            id: _nextCrop++,
            fieldId: id,
            cropType: body['cropType']! as String,
            variety: body['variety']! as String,
            plantingDate: body['plantingDate']! as String,
            expectedHarvestDate: body['expectedHarvestDate']! as String,
            expectedQuantity: body['expectedQuantity']! as num,
          );
          this.crops.add(crop);
          return FakeResponse(201, crop);
        });
    }

    api
      ..on(
        'GET',
        '/api/crops/mine',
        (_) => FakeResponse(200, [
          for (final crop in this.crops)
            farmerCropJson(id: crop['cropId']! as int, cropType: crop['cropType']! as String),
        ]),
      )
      ..on('GET', '/api/issues/mine', (request) {
        final page = int.parse(request.query['page'] ?? '1');
        final pageSize = int.parse(request.query['pageSize'] ?? '20');
        final items = this.issues.skip((page - 1) * pageSize).take(pageSize).toList();
        return FakeResponse(200, {
          'items': items,
          'page': page,
          'pageSize': pageSize,
          'totalCount': this.issues.length,
          'totalPages': (this.issues.length / pageSize).ceil(),
        });
      })
      ..on('POST', '/api/issues', (request) => _report(request.json, hasPhoto: false))
      ..on('POST', '/api/issues/with-photo', (request) {
        final form = request.body! as FormData;
        return _report({for (final field in form.fields) field.key: field.value}, hasPhoto: true);
      });
    for (var id = 20; id <= 29; id++) {
      api.on('GET', '/api/advisories/$id', (_) {
        final advisory = this.advisories[id];
        // A farmer can't see an advisory that hasn't been released.
        return advisory == null || advisory['status'] == 'Draft'
            ? const FakeResponse(404)
            : FakeResponse(200, advisory);
      });
    }

    for (var id = 100; id <= 109; id++) {
      api
        ..on('GET', '/api/crops/$id', (_) => FakeResponse(200, _crop(id)))
        ..on('PUT', '/api/crops/$id', (request) {
          final index = this.crops.indexWhere((crop) => crop['cropId'] == id);
          this.crops[index] = {...this.crops[index], 'status': request.json['status']};
          return FakeResponse(200, this.crops[index]);
        });
    }
  }

  final FakeApi api;
  final List<Map<String, Object?>> farms;
  final List<Map<String, Object?>> fields;
  final List<Map<String, Object?>> crops;

  /// The farmer's issues, newest first.
  final List<Map<String, Object?>> issues;

  /// Advisories by id, for ids 20 to 29.
  final Map<int, Map<String, Object?>> advisories;

  /// The status of the advisory a newly reported issue gets: `Draft` unless the photo model was
  /// confident enough to release `Preliminary` advice straight away.
  String newIssueAdvisoryStatus = 'Draft';

  int _nextFarm = 2;
  int _nextField = 11;
  int _nextCrop = 101;
  int _nextIssue = 50;
  int _nextAdvisory = 25;

  FakeResponse _report(Map<String, Object?> body, {required bool hasPhoto}) {
    final advisoryId = _nextAdvisory++;
    final issue = issueJson(
      id: _nextIssue++,
      title: body['title']! as String,
      description: body['description']! as String,
      severity: body['severity']! as String,
      advisoryId: advisoryId,
      advisoryStatus: newIssueAdvisoryStatus,
      hasPhoto: hasPhoto,
      createdAt: '2026-09-25T10:00:00',
    );
    issues.insert(0, issue);
    advisories[advisoryId] = farmerAdvisoryJson(status: newIssueAdvisoryStatus);
    return FakeResponse(201, issue);
  }

  Map<String, Object?> _crop(int id) => crops.firstWhere((crop) => crop['cropId'] == id);
}

/// Starts the app signed in as a farmer, who lands on the farms list.
Future<TestApp> pumpFarmer(
  WidgetTester tester,
  FarmerBackend backend, {
  String language = 'en',
  Size screen = const Size(390, 844),
  List<Override> overrides = const [],
  FakePermissions? permissions,
}) => pumpAgriLink(
  tester,
  api: backend.api,
  session: Session(token: fakeJwt(), role: Role.farmer),
  language: language,
  screen: screen,
  overrides: overrides,
  permissions: permissions,
);
