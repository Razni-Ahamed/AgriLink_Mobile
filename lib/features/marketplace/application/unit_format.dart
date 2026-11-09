import '../../../core/format/formatters.dart';
import '../../../l10n/l10n.dart';
import '../data/marketplace_enums.dart';

/// Quantities and prices written with their listing's unit, like the website's `useUnits`:
/// `format.quantity(l10n, 3, QuantityUnit.bunch)` → "3 bunches",
/// `format.pricePer(l10n, 120, QuantityUnit.kg)` → "Rs 120/kg".
extension UnitFormatters on Formatters {
  String quantity(AppLocalizations l10n, num value, QuantityUnit unit) {
    final amount = number(value);
    final one = value == 1;
    return switch (unit) {
      QuantityUnit.kg =>
        one ? l10n.commonUnitsQuantityKgOne(amount) : l10n.commonUnitsQuantityKgOther(amount),
      QuantityUnit.piece =>
        one ? l10n.commonUnitsQuantityPieceOne(amount) : l10n.commonUnitsQuantityPieceOther(amount),
      QuantityUnit.bunch =>
        one ? l10n.commonUnitsQuantityBunchOne(amount) : l10n.commonUnitsQuantityBunchOther(amount),
      QuantityUnit.sack =>
        one ? l10n.commonUnitsQuantitySackOne(amount) : l10n.commonUnitsQuantitySackOther(amount),
      QuantityUnit.crate =>
        one ? l10n.commonUnitsQuantityCrateOne(amount) : l10n.commonUnitsQuantityCrateOther(amount),
    };
  }

  /// "Rs 120/kg".
  String pricePer(AppLocalizations l10n, num value, QuantityUnit unit) =>
      l10n.commonUnitsPricePer(number(value), unitPer(l10n, unit));
}

/// "kg", "bunch": for labels like "Price per bunch (Rs)".
String unitPer(AppLocalizations l10n, QuantityUnit unit) => switch (unit) {
  QuantityUnit.kg => l10n.commonUnitsPerKg,
  QuantityUnit.piece => l10n.commonUnitsPerPiece,
  QuantityUnit.bunch => l10n.commonUnitsPerBunch,
  QuantityUnit.sack => l10n.commonUnitsPerSack,
  QuantityUnit.crate => l10n.commonUnitsPerCrate,
};

/// "Kilograms (kg)", "Bunches": the choices in the unit picker.
String unitName(AppLocalizations l10n, QuantityUnit unit) => switch (unit) {
  QuantityUnit.kg => l10n.commonUnitsNameKg,
  QuantityUnit.piece => l10n.commonUnitsNamePiece,
  QuantityUnit.bunch => l10n.commonUnitsNameBunch,
  QuantityUnit.sack => l10n.commonUnitsNameSack,
  QuantityUnit.crate => l10n.commonUnitsNameCrate,
};
