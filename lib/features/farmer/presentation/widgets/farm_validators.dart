import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../application/farm_limits.dart';

/// Validators for the farm, field and crop forms, with the website's messages.

/// A name that is required and no longer than the API allows.
FormFieldValidator<String> nameValidator(AppLocalizations l10n) => (value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return l10n.commonValidationNameRequired;
  }
  return text.length > FarmLimits.nameMaxLength ? l10n.commonValidationNameTooLong : null;
};

/// An area in acres: a number from 0.01 to 100,000.
FormFieldValidator<String> areaValidator(AppLocalizations l10n) => (value) {
  final area = parseDecimal(value ?? '');
  if (area == null || area < FarmLimits.areaMin) {
    return l10n.commonValidationAreaMin;
  }
  return area > FarmLimits.areaMax ? l10n.farmsFormAreaTooLarge : null;
};

/// The expected harvest in kilograms: a number from 0.01 to 1,000,000.
FormFieldValidator<String> quantityValidator(AppLocalizations l10n) => (value) {
  final quantity = parseDecimal(value ?? '');
  if (quantity == null || quantity < FarmLimits.quantityMin) {
    return l10n.commonValidationQuantityMin;
  }
  return quantity > FarmLimits.quantityMax ? l10n.farmsFormQuantityTooLarge : null;
};
