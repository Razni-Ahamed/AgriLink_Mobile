import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/validation/validators.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';

enum UsernameStatus {
  /// Nothing typed yet.
  idle,

  /// The signed-in user's own current username.
  unchanged,

  /// Breaks a local rule; the field's own validation message says which.
  invalid,
  reserved,
  checking,
  available,
  taken,

  /// The check itself failed. The server checks again on save.
  error,
}

/// The live "is this username free?" check under a username field, like the website's
/// `useUsernameAvailability`: local rules first (so a bad name costs no request), then one
/// request once typing pauses for [debounce]. Only advisory: the server checks again on save.
class UsernameAvailabilityChecker extends ValueNotifier<UsernameStatus> {
  UsernameAvailabilityChecker(
    this._api, {
    this.currentUsername,
    this.debounce = const Duration(milliseconds: 400),
  }) : super(UsernameStatus.idle);

  final AuthApi _api;

  /// When editing a profile: this name belongs to the user, so it isn't "taken".
  final String? currentUsername;
  final Duration debounce;

  Timer? _timer;
  CancelToken? _inFlight;
  String _latest = '';
  final Map<String, UsernameStatus> _cache = {};

  /// Call on every change of the field.
  void update(String raw) {
    final username = normalizeUsername(raw);
    _latest = username;
    _timer?.cancel();
    _inFlight?.cancel();

    if (username.isEmpty) {
      value = UsernameStatus.idle;
      return;
    }
    if (currentUsername != null && username == normalizeUsername(currentUsername!)) {
      value = UsernameStatus.unchanged;
      return;
    }
    final problem = usernameProblem(username);
    if (problem != null) {
      value = problem == UsernameProblem.reserved
          ? UsernameStatus.reserved
          : UsernameStatus.invalid;
      return;
    }
    final cached = _cache[username];
    if (cached != null) {
      value = cached;
      return;
    }
    value = UsernameStatus.checking;
    _timer = Timer(debounce, () => _check(username));
  }

  Future<void> _check(String username) async {
    final cancelToken = _inFlight = CancelToken();
    try {
      final result = await _api.checkUsername(username, cancelToken: cancelToken);
      final status = result.available
          ? UsernameStatus.available
          : switch (result.reason) {
              UsernameUnavailableReason.reserved => UsernameStatus.reserved,
              UsernameUnavailableReason.invalid => UsernameStatus.invalid,
              _ => UsernameStatus.taken,
            };
      _cache[username] = status;
      if (_latest == username) {
        value = status;
      }
    } on Object {
      if (_latest == username && !cancelToken.isCancelled) {
        value = UsernameStatus.error;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inFlight?.cancel();
    super.dispose();
  }
}
