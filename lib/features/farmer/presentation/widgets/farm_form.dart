import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_error_parser.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/district_picker.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../application/farm_limits.dart';
import '../../application/farms.dart';
import '../../data/farm.dart';
import '../../data/farms_api.dart';
import 'farm_validators.dart';
import 'form_sheet.dart';

/// Adds a farm, or edits [farm]. Returns the saved farm, or null if it was closed.
Future<Farm?> showFarmFormSheet(BuildContext context, {Farm? farm}) {
  final l10n = context.l10n;
  return showFormSheet<Farm>(
    context,
    title: farm == null ? l10n.farmsListNewFarm : l10n.farmsDetailEditFarm,
    form: FarmForm(farm: farm),
  );
}

/// The API's names for the fields this form has, so its validation errors show under them.
const _serverFieldNames = {'Name': 'name', 'District': 'district', 'Area': 'area'};

/// The form for a farm: name, district and area in acres. The same rules as the website.
class FarmForm extends ConsumerStatefulWidget {
  const FarmForm({super.key, this.farm});

  /// The farm being edited; null when adding one.
  final Farm? farm;

  @override
  ConsumerState<FarmForm> createState() => _FarmFormState();
}

class _FarmFormState extends ConsumerState<FarmForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.farm?.name);
  late final _area = TextEditingController(
    text: widget.farm == null ? null : plainNumber(widget.farm!.area),
  );
  late String? _district = widget.farm?.district;

  bool _saving = false;
  Map<String, String> _fieldErrors = const {};
  List<String> _generalErrors = const [];

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  void _clearError(String field) {
    if (_fieldErrors.containsKey(field)) {
      setState(() => _fieldErrors = {..._fieldErrors}..remove(field));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l10n = context.l10n;
    final input = FarmInput(
      name: _name.text.trim(),
      district: _district!,
      area: parseDecimal(_area.text)!,
    );
    final api = ref.read(farmsApiProvider);
    final editing = widget.farm;
    setState(() {
      _saving = true;
      _fieldErrors = const {};
      _generalErrors = const [];
    });
    try {
      final saved = editing == null
          ? await api.createFarm(input)
          : await api.updateFarm(editing.id, input);
      if (!mounted) {
        return;
      }
      ref.invalidate(myFarmsProvider);
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
    final editing = widget.farm != null;
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
            AppTextField(
              fieldKey: const Key('farm-name'),
              controller: _name,
              label: l10n.farmsFormFarmName,
              textCapitalization: TextCapitalization.words,
              maxLength: FarmLimits.nameMaxLength * 2,
              enabled: !_saving,
              validator: nameValidator(l10n),
              serverError: _fieldErrors['name'],
              onChanged: (_) => _clearError('name'),
            ),
            const SizedBox(height: Gaps.md),
            DistrictPicker(
              key: const Key('farm-district'),
              value: _district,
              onChanged: (district) {
                setState(() => _district = district);
                _clearError('district');
              },
              validator: (value) =>
                  (value ?? '').isEmpty ? l10n.commonValidationDistrictRequired : null,
              serverError: _fieldErrors['district'],
            ),
            const SizedBox(height: Gaps.md),
            AppTextField(
              fieldKey: const Key('farm-area'),
              controller: _area,
              label: l10n.farmsFormArea,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              enabled: !_saving,
              validator: areaValidator(l10n),
              serverError: _fieldErrors['area'],
              onChanged: (_) => _clearError('area'),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Gaps.lg),
            LoadingButton(
              key: const Key('farm-submit'),
              label: editing ? l10n.farmsDetailSaveChanges : l10n.farmsListCreateFarm,
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
