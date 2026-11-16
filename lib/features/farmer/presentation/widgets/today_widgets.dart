import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/canopy/motion.dart';
import '../../../../shared/canopy/photo_banner.dart';
import '../../../../shared/canopy/season_vine.dart';
import '../../../../shared/media/crop_photos.dart';
import '../../data/crop.dart';
import '../../data/weather.dart';

/// A growing crop as its own photo, with the season on a glass panel over the bottom: a vine that
/// grows to today, the day count and how long until harvest. The website's `CropSeasonCard`.
class CropSeasonCard extends StatelessWidget {
  const CropSeasonCard({super.key, required this.crop, required this.onTap});

  final FarmerCrop crop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final season = SeasonProgress.of(crop.plantingDate, crop.expectedHarvestDate);
    final name = cropLabel(l10n, crop.cropType);
    const white = Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Material(
        color: Colors.black,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(cropPhotoAsset(crop.cropType), fit: BoxFit.cover),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xB304100B), Color(0x0004100B), Color(0x3304100B)],
                        stops: [0, 0.48, 1],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: textTheme.headlineSmall?.copyWith(color: white),
                                  ),
                                  Text(
                                    [
                                      crop.variety,
                                      crop.fieldName,
                                    ].where((part) => part.isNotEmpty).join(', '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: white.withValues(alpha: 0.25)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                child: Text(
                                  statusLabel(l10n, StatusKind.crop, crop.status.apiName),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      SeasonGlass(name: name, season: season),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The weather for the farmer's district on dark glass: an animated sky, the temperature, the
/// next few hours and one line of farm advice. Says so plainly when the forecast can't load.
class WeatherCard extends ConsumerWidget {
  const WeatherCard({super.key, required this.district});

  final String district;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final forecast = ref.watch(districtForecastProvider(district));
    const white = Colors.white;

    return BannerGlass(
      padding: const EdgeInsets.all(14),
      child: forecast.when(
        loading: () => const SizedBox(height: 110),
        error: (_, _) => Row(
          children: [
            const Icon(Icons.cloud_off_outlined),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.farmsWeatherUnavailable)),
          ],
        ),
        data: (weather) {
          final kind = weatherKind(weather.weatherCode, isDay: weather.isDay);
          final advice = weatherAdvice(weather);
          final adviceText = switch (advice) {
            HeavyRain(:final mm) => l10n.farmsWeatherAdviceHeavyRain(mm),
            RainSoon(:final time) => l10n.farmsWeatherAdviceRainSoon(forecastHour(time)),
            HotDay() => l10n.farmsWeatherAdviceHot,
            Calm() => l10n.farmsWeatherAdviceCalm,
          };
          return Semantics(
            container: true,
            label: l10n.farmsWeatherLabel(districtLabel(l10n, weather.district)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    WeatherIcon(kind: kind, size: 64),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${weather.temperatureC.round()}°',
                          style: textTheme.displaySmall?.copyWith(color: white, height: 1),
                        ),
                        Text(
                          '${weatherKindLabel(l10n, kind)} · ${districtLabel(l10n, weather.district)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: white.withValues(alpha: 0.78),
                          ),
                        ),
                        if (weather.maxC != null && weather.minC != null)
                          Text(
                            l10n.farmsWeatherRange(weather.maxC!.round(), weather.minC!.round()),
                            style: textTheme.labelSmall?.copyWith(
                              color: white.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (weather.hours.isNotEmpty) ...[
                  Divider(height: 20, color: white.withValues(alpha: 0.12)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final hour in weather.hours)
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                forecastHour(hour.time),
                                style: textTheme.labelSmall?.copyWith(
                                  color: white.withValues(alpha: 0.7),
                                ),
                              ),
                              WeatherIcon(
                                kind: weatherKind(hour.weatherCode),
                                size: 26,
                                animate: false,
                              ),
                              Text(
                                hour.temperatureC == null ? '–' : '${hour.temperatureC!.round()}°',
                                style: textTheme.labelLarge?.copyWith(color: white),
                              ),
                              if ((hour.rainChancePercent ?? 0) > 0)
                                Text(
                                  '${hour.rainChancePercent}%',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF9FD0E6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  Divider(height: 20, color: white.withValues(alpha: 0.12)),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (advice is! Calm) ...[
                      const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFEFC062)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(adviceText, style: textTheme.bodySmall?.copyWith(color: white)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String weatherKindLabel(AppLocalizations l10n, WeatherKind kind) => switch (kind) {
  WeatherKind.clear => l10n.farmsWeatherKindClear,
  WeatherKind.night => l10n.farmsWeatherKindNight,
  WeatherKind.partly => l10n.farmsWeatherKindPartly,
  WeatherKind.cloudy => l10n.farmsWeatherKindCloudy,
  WeatherKind.fog => l10n.farmsWeatherKindFog,
  WeatherKind.rain => l10n.farmsWeatherKindRain,
  WeatherKind.storm => l10n.farmsWeatherKindStorm,
};

/// An animated weather picture: the sun's rays turn slowly, clouds drift, rain falls. Holds still
/// with Lite or Off motion, or when [animate] is false (the small hourly icons).
class WeatherIcon extends ConsumerStatefulWidget {
  const WeatherIcon({super.key, required this.kind, required this.size, this.animate = true});

  final WeatherKind kind;
  final double size;
  final bool animate;

  @override
  ConsumerState<WeatherIcon> createState() => _WeatherIconState();
}

class _WeatherIconState extends ConsumerState<WeatherIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moving = widget.animate && motionLevel(context, ref) == MotionLevel.full;
    if (moving && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!moving && _controller.isAnimating) {
      _controller.stop();
    }
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _WeatherPainter(kind: widget.kind, t: moving ? _controller.value : 0),
        ),
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter({required this.kind, required this.t});

  final WeatherKind kind;

  /// 0–1 through the loop.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 88;
    canvas.scale(s);
    const sunColor = Color(0xFFEFC062);
    const cloudColor = Color(0xFFE8EFE6);
    final sun = kind == WeatherKind.clear || kind == WeatherKind.partly;
    final cloud = kind != WeatherKind.clear && kind != WeatherKind.night;
    final rain = kind == WeatherKind.rain || kind == WeatherKind.storm;

    if (sun) {
      final rays = Paint()
        ..color = sunColor
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.save();
      canvas.translate(34, 30);
      canvas.rotate(t * math.pi / 2);
      for (var i = 0; i < 8; i++) {
        canvas.drawLine(const Offset(0, -23), const Offset(0, -18), rays);
        canvas.rotate(math.pi / 4);
      }
      canvas.restore();
      canvas.drawCircle(const Offset(34, 30), 13, Paint()..color = sunColor);
    }
    if (kind == WeatherKind.night) {
      final moon = Path()..addOval(Rect.fromCircle(center: const Offset(40, 34), radius: 18));
      final bite = Path()..addOval(Rect.fromCircle(center: const Offset(50, 26), radius: 15));
      canvas.drawPath(
        Path.combine(PathOperation.difference, moon, bite),
        Paint()..color = cloudColor,
      );
    }
    if (cloud) {
      final drift = math.sin(t * math.pi * 2) * 3.5;
      canvas.save();
      canvas.translate(drift, 0);
      final small = kind == WeatherKind.partly;
      final paint = Paint()
        ..color = kind == WeatherKind.storm ? const Color(0xFFB8C4BC) : cloudColor;
      if (small) {
        canvas.drawRRect(RRect.fromLTRBR(26, 44, 80, 60, const Radius.circular(8)), paint);
        canvas.drawCircle(const Offset(48, 42), 12, paint);
        canvas.drawCircle(const Offset(64, 46), 10, paint);
      } else {
        canvas.drawRRect(RRect.fromLTRBR(14, 40, 80, 58, const Radius.circular(9)), paint);
        canvas.drawCircle(const Offset(36, 38), 14, paint);
        canvas.drawCircle(const Offset(56, 34), 17, paint);
      }
      canvas.restore();
    }
    if (kind == WeatherKind.fog) {
      final fog = Paint()
        ..color = cloudColor.withValues(alpha: 0.8)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(16, 66), const Offset(70, 66), fog);
      canvas.drawLine(const Offset(24, 74), const Offset(78, 74), fog);
    }
    if (rain) {
      final drops = Paint()
        ..color = const Color(0xFF9FD0E6)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final x = 34.0 + i * 12;
        final fall = ((t * 4 + i / 3) % 1) * 10;
        canvas.drawLine(Offset(x, 62 + fall), Offset(x - 2, 68 + fall), drops);
      }
    }
    if (kind == WeatherKind.storm && (t * 4) % 1 > 0.85) {
      final bolt = Path()
        ..moveTo(50, 58)
        ..lineTo(43, 70)
        ..lineTo(49, 70)
        ..lineTo(45, 80)
        ..lineTo(56, 66)
        ..lineTo(50, 66)
        ..close();
      canvas.drawPath(bolt, Paint()..color = const Color(0xFFEFC062));
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) => old.t != t || old.kind != kind;
}

/// The glass strip with a crop's season on it: the vine grown to today, the day of the season,
/// and how long until harvest. Sits on the crop's photo (the Today card, the crop page).
class SeasonGlass extends StatelessWidget {
  const SeasonGlass({super.key, required this.name, required this.season});

  /// The crop's name, for screen readers.
  final String name;
  final SeasonProgress season;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    const white = Colors.white;
    return BannerGlass(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SeasonVine(
            fraction: season.fraction,
            label: l10n.farmsTodayVineLabel(name, season.day, season.total),
            color: const Color(0xFFB5CDA0),
            trackColor: white.withValues(alpha: 0.22),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Both sides can shrink and wrap, so long Sinhala and Tamil text and large system
              // fonts never push past the card.
              Flexible(
                child: Text(
                  l10n.farmsTodayDay(season.day, season.total),
                  style: textTheme.labelMedium?.copyWith(color: white, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  season.daysLeft > 0
                      ? (season.daysLeft == 1
                            ? l10n.farmsTodayHarvestInOne(season.daysLeft)
                            : l10n.farmsTodayHarvestInOther(season.daysLeft))
                      : l10n.farmsTodayHarvestDue,
                  textAlign: TextAlign.end,
                  style: textTheme.labelMedium?.copyWith(color: white.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
