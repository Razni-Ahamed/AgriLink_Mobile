import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/session/session_controller.dart';

/// `GET /api/weather/{district}`: what it is like now, today's range and rain, and the next few
/// hours. Times are local Sri Lanka time ("2026-11-15T15:00"); codes are WMO weather codes.
class DistrictForecast {
  const DistrictForecast({
    required this.district,
    required this.currentTime,
    required this.temperatureC,
    required this.weatherCode,
    required this.isDay,
    required this.maxC,
    required this.minC,
    required this.rainMm,
    required this.hours,
  });

  factory DistrictForecast.fromJson(Json json) {
    final current = asJson(json['current']);
    final today = asJson(json['today']);
    double? number(Object? value) => (value as num?)?.toDouble();
    return DistrictForecast(
      district: json['district'] as String? ?? '',
      currentTime: current['time'] as String? ?? '',
      temperatureC: number(current['temperatureC']) ?? 0,
      weatherCode: (current['weatherCode'] as num?)?.toInt() ?? 0,
      isDay: current['isDay'] as bool? ?? true,
      maxC: number(today['maxC']),
      minC: number(today['minC']),
      rainMm: number(today['rainMm']),
      hours: [
        for (final item in asJsonList(json['hours']))
          ForecastHour(
            time: item['time'] as String? ?? '',
            temperatureC: number(item['temperatureC']),
            rainChancePercent: (item['rainChancePercent'] as num?)?.toInt(),
            weatherCode: (item['weatherCode'] as num?)?.toInt(),
          ),
      ],
    );
  }

  final String district;
  final String currentTime;
  final double temperatureC;
  final int weatherCode;
  final bool isDay;
  final double? maxC;
  final double? minC;
  final double? rainMm;
  final List<ForecastHour> hours;
}

class ForecastHour {
  const ForecastHour({
    required this.time,
    required this.temperatureC,
    required this.rainChancePercent,
    required this.weatherCode,
  });

  final String time;
  final double? temperatureC;
  final int? rainChancePercent;
  final int? weatherCode;
}

/// The forecast for a district. The server caches each district for half an hour; a failed fetch
/// leaves the card saying the weather isn't available.
final districtForecastProvider = FutureProvider.autoDispose.family<DistrictForecast, String>((
  ref,
  district,
) {
  ref.watch(sessionTokenProvider);
  return ref
      .watch(apiClientProvider)
      .get(
        '/api/weather/${Uri.encodeComponent(district)}',
        decode: (data) => DistrictForecast.fromJson(asJson(data)),
      );
});

enum WeatherKind { clear, night, partly, cloudy, fog, rain, storm }

/// WMO weather code → the picture and words we show for it. The website's `weatherKind`.
WeatherKind weatherKind(int? code, {bool isDay = true}) {
  if (code == null) return WeatherKind.cloudy;
  if (code == 0) return isDay ? WeatherKind.clear : WeatherKind.night;
  if (code <= 2) return isDay ? WeatherKind.partly : WeatherKind.night;
  if (code == 3) return WeatherKind.cloudy;
  if (code == 45 || code == 48) return WeatherKind.fog;
  if (code >= 95) return WeatherKind.storm;
  return WeatherKind.rain;
}

sealed class WeatherAdvice {
  const WeatherAdvice();
}

class HeavyRain extends WeatherAdvice {
  const HeavyRain(this.mm);
  final int mm;
}

class RainSoon extends WeatherAdvice {
  const RainSoon(this.time);
  final String time;
}

class HotDay extends WeatherAdvice {
  const HotDay();
}

class Calm extends WeatherAdvice {
  const Calm();
}

/// Rain chance at or above which an hour counts as "rain likely".
const int rainLikelyPercent = 60;

/// Rain in a day at or above which fields may flood or wash.
const double heavyRainMm = 25;

/// A day's high at or above which plants need water outside the heat of the day.
const double hotDayC = 33;

/// One line of farm advice, most urgent first: heavy rain today, then rain in the coming hours
/// (hold spraying, it would wash off), then heat (water morning or evening). Same rules as the
/// website's `weatherAdvice`.
WeatherAdvice weatherAdvice(DistrictForecast forecast) {
  if ((forecast.rainMm ?? 0) >= heavyRainMm) return HeavyRain(forecast.rainMm!.round());
  final now = weatherKind(forecast.weatherCode);
  if (now == WeatherKind.rain || now == WeatherKind.storm) return RainSoon(forecast.currentTime);
  for (final hour in forecast.hours) {
    if ((hour.rainChancePercent ?? 0) >= rainLikelyPercent) return RainSoon(hour.time);
  }
  if ((forecast.maxC ?? 0) >= hotDayC) return const HotDay();
  return const Calm();
}

/// "15:00" from a local Sri Lanka time string.
String forecastHour(String time) {
  final clock = time.split('T').length > 1 ? time.split('T')[1] : time;
  return clock.length >= 5 ? clock.substring(0, 5) : clock;
}
