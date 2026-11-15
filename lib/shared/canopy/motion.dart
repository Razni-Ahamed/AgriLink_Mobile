import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/preferences.dart';

/// How much the app moves, the same setting as the website's "Animations".
///
/// * [full]: glass blur, springs, growing vines, rolling numbers, slow loops.
/// * [lite]: no blur and no background loops: solid panels, cheap on slow phones.
/// * [off]: nothing animates.
///
/// [system], the default, is [off] when Android's "Remove animations" is on and [full] otherwise.
enum MotionPreference { system, full, lite, off }

enum MotionLevel { full, lite, off }

final motionPreferenceProvider = NotifierProvider<MotionPreferenceController, MotionPreference>(
  MotionPreferenceController.new,
);

class MotionPreferenceController extends Notifier<MotionPreference> {
  @override
  MotionPreference build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(PrefKeys.motion);
    return MotionPreference.values.firstWhere(
      (preference) => preference.name == stored,
      orElse: () => MotionPreference.system,
    );
  }

  Future<void> setPreference(MotionPreference preference) async {
    state = preference;
    await ref.read(sharedPreferencesProvider).setString(PrefKeys.motion, preference.name);
  }
}

/// The level in use here: the user's choice, or for [MotionPreference.system] the device's.
MotionLevel motionLevel(BuildContext context, WidgetRef ref) {
  return switch (ref.watch(motionPreferenceProvider)) {
    MotionPreference.full => MotionLevel.full,
    MotionPreference.lite => MotionLevel.lite,
    MotionPreference.off => MotionLevel.off,
    MotionPreference.system =>
      MediaQuery.disableAnimationsOf(context) ? MotionLevel.off : MotionLevel.full,
  };
}

/// The app's motion vocabulary, the Flutter twin of the website's `lib/motion.ts`.
abstract final class Motion {
  /// Presses and toggles.
  static const Duration tap = Duration(milliseconds: 160);

  /// Something moving to a new place: a highlight, a card.
  static const Duration move = Duration(milliseconds: 380);

  /// A sheet rising, a photo settling, a vine growing.
  static const Duration reveal = Duration(milliseconds: 520);

  /// A spring that overshoots a little and lands, like a drop of water.
  static const Curve springy = Cubic(0.22, 1.2, 0.36, 1);
  static const Curve out = Cubic(0.2, 0.8, 0.2, 1);

  /// [duration], or zero when motion is off.
  static Duration of(MotionLevel level, Duration duration) =>
      level == MotionLevel.off ? Duration.zero : duration;
}
