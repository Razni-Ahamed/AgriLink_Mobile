import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_error_parser.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../application/farm_limits.dart';
import '../../application/farms.dart';
import '../../data/crop.dart';
import '../../data/crops_api.dart';
import 'crop_type_picker.dart';
import 'farm_validators.dart';
import 'form_sheet.dart';

/// Plants a crop in the field with id [fieldId]. Returns the new crop, or null if it was closed.
Future<Crop?> showCropFormSheet(BuildContext context, {required int fieldId}) {
  return showFormSheet<Crop>(
    context,
    title: context.l10n.farmsFieldPlantCrop,
    form: CropForm(fieldId: fieldId),
  );
}

const _serverFieldNames = {
  'CropType': 'cropType',
  'Variety': 'variety',
  'PlantingDate': 'plantingDate',
  'ExpectedHarvestDate': 'harvestDate',
  'ExpectedQuantity': 'quantity',
};

/// The form for planting a crop: type (from the API's list), variety, the two dates and the
/// expected quantity in kilograms. The harvest must be after the planting, like the website.
class CropForm extends ConsumerStatefulWidget {
  const CropForm({super.key, required this.fieldId});

  final int fieldId;

  @override
  ConsumerState<CropForm> createState() => _CropFormState();
}

class _CropFormState extends ConsumerState<CropForm> {
  final _formKey = GlobalKey<FormState>();
  final _variety = TextEditingController();
  final _quantity = TextEditingController();

  String? _cropType;
  DateTime? _plantingDate;
  DateTime? _harvestDate;

  bool _saving = false;

  /// Whether the farmer has tried to save yet. From then on the dates are checked again as they
  /// change, so an old "harvest must be after planting" doesn't linger after they fix it.
  bool _submitted = false;
  Map<String, String> _fieldErrors = const {};
  List<String> _generalErrors = const [];

  @override
  void dispose() {
    _variety.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _clearError(String field) {
    if (_fieldErrors.containsKey(field)) {
      setState(() => _fieldErrors = {..._fieldErrors}..remove(field));
    }
  }

  /// The date fields only check themselves when the whole form does, so ask again once the
  /// new date is in place.
  void _revalidateDates() {
    if (!_submitted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _formKey.currentState?.validate();
      }
    });
  }

  Future<void> _submit() async {
    _submitted = true;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l10n = context.l10n;
    final input = CropInput(
      cropType: _cropType!,
      variety: _variety.text.trim(),
      plantingDate: _plantingDate!,
      expectedHarvestDate: _harvestDate!,
      expectedQuantity: parseDecimal(_quantity.text)!,
    );
    final api = ref.read(cropsApiProvider);
    setState(() {
      _saving = true;
      _fieldErrors = const {};
      _generalErrors = const [];
    });
    try {
      final saved = await api.plant(widget.fieldId, input);
      if (!mounted) {
        return;
      }
      ref
        ..invalidate(fieldCropsProvider(widget.fieldId))
        ..invalidate(myCropsProvider);
      Navigator.of(context).pop(saved);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final parsed = parseApiError(
        error,
        l10n,
        generic: (l) => l.farmsFormSaveError,
        serverFieldNames: _serverFieldNames,
      );
      setState(() {
        _saving = false;
        _fieldErrors = parsed.fieldErrors;
        _generalErrors = parsed.generalErrors;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_generalErrors.isNotEmpty) ...[
              ErrorBanner(messages: _generalErrors),
              const SizedBox(height: Gaps.md),
            ],
            CropTypePicker(
              key: const Key('crop-type'),
              value: _cropType,
              onChanged: (type) {
                setState(() => _cropType = type);
                _clearError('cropType');
              },
              validator: (value) =>
                  (value ?? '').isEmpty ? l10n.commonValidationCropTypeRequired : null,
              serverError: _fieldErrors['cropType'],
            ),
            const SizedBox(height: Gaps.md),
            AppTextField(
              fieldKey: const Key('crop-variety'),
              controller: _variety,
              label: l10n.farmsFormVariety,
              textCapitalization: TextCapitalization.words,
              maxLength: FarmLimits.nameMaxLength,
              enabled: !_saving,
              serverError: _fieldErrors['variety'],
              onChanged: (_) => _clearError('variety'),
            ),
            const SizedBox(height: Gaps.md),
            AppDateField(
              key: const Key('crop-planting-date'),
              label: l10n.farmsFormPlantingDate,
              value: _plantingDate,
              onChanged: (date) {
                setState(() => _plantingDate = date);
                _clearError('plantingDate');
                _revalidateDates();
              },
              validator: (value) =>
                  value == null ? l10n.commonValidationPlantingDateRequired : null,
              serverError: _fieldErrors['plantingDate'],
            ),
            const SizedBox(height: Gaps.md),
            AppDateField(
              key: const Key('crop-harvest-date'),
              label: l10n.farmsFormExpectedHarvestDate,
              value: _harvestDate,
              onChanged: (date) {
                setState(() => _harvestDate = date);
                _clearError('harvestDate');
                _revalidateDates();
              },
              validator: (value) {
                if (value == null) {
                  return l10n.commonValidationExpectedHarvestDateRequired;
                }
                final planting = _plantingDate;
                return planting != null && !value.isAfter(planting)
                    ? l10n.commonValidationHarvestAfterPlanting
                    : null;
              },
              serverError: _fieldErrors['harvestDate'],
            ),
            const SizedBox(height: Gaps.md),
            AppTextField(
              fieldKey: const Key('crop-quantity'),
              controller: _quantity,
              label: l10n.farmsFormExpectedQuantity,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              enabled: !_saving,
              validator: quantityValidator(l10n),
              serverError: _fieldErrors['quantity'],
              onChanged: (_) => _clearError('quantity'),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Gaps.lg),
            LoadingButton(
              key: const Key('crop-submit'),
              label: l10n.farmsFieldPlantCropSubmit,
              loadingLabel: l10n.commonActionsSaving,
              loading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
