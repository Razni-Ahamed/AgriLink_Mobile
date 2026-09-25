import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../l10n/locale_controller.dart';

/// Numbers, prices and dates in the chosen language's Sri Lankan locale (`en_LK`, `si_LK`,
/// `ta_LK`), like the website's `formatQuantity` and `formatDate`. The unit stays in the
/// translation (`Rs {value}`), because word order around it differs by language.
///
/// ```dart
/// final format = ref.watch(formattersProvider);
/// Text(format.rupees(l10n, listing.pricePerUnit), style: textTheme.titleMedium!.mono);
/// Text(format.date(order.createdAt));
/// ```
class Formatters {
  Formatters(AppLanguage language)
    : numberLocale = Intl.verifiedLocale(
        language.intlLocale,
        NumberFormat.localeExists,
        onFailure: (_) => language.name,
      )!,
      dateLocale = Intl.verifiedLocale(
        language.intlLocale,
        DateFormat.localeExists,
        onFailure: (_) => language.name,
      )!;

  final String numberLocale;
  final String dateLocale;

  /// Up to two decimals, grouped: 1250.5 → "1,250.5".
  String number(num value) {
    final format = NumberFormat.decimalPattern(numberLocale)
      ..maximumFractionDigits = 2;
    return format.format(value);
  }

  /// "Rs 1,250.5", formatted like the website's prices.
  String rupees(AppLocalizations l10n, num value) =>
      l10n.commonUnitsRupees(number(value));

  String rupeesPerUnit(AppLocalizations l10n, num value) =>
      l10n.commonUnitsRupeesPerUnit(number(value));

  String kilograms(AppLocalizations l10n, num value) =>
      l10n.commonUnitsKg(number(value));

  /// "25 Sept 2026" in the phone's time zone.
  String date(DateTime value) =>
      DateFormat.yMMMd(dateLocale).format(value.toLocal());

  /// "25 Sept 2026, 3:40 PM" in the phone's time zone.
  String dateTime(DateTime value) =>
      DateFormat.yMMMd(dateLocale).add_jm().format(value.toLocal());
}

final formattersProvider = Provider<Formatters>(
  (ref) => Formatters(ref.watch(languageProvider)),
);
