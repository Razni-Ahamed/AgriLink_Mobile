import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_error_parser.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../application/farm_limits.dart';
import '../../application/farms.dart';
import '../../data/farm.dart';
import '../../data/farms_api.dart';
import 'farm_validators.dart';
import 'form_sheet.dart';

/// Adds a field to the farm with id [farmId]. Returns the new field, or null if it was closed.
/// (The API can add fields but not edit or delete them.)
Future<FarmField?> showFieldFormSheet(BuildContext context, {required int farmId}) {
  return showFormSheet<FarmField>(
    context,
    title: context.l10n.farmsDetailAddField,
    form: FieldForm(farmId: farmId),
  );
}

const _serverFieldNames = {'Name': 'name', 'Area': 'area'};

/// The form for a new field: a name and an area in acres.
class FieldForm extends ConsumerStatefulWidget {
  const FieldForm({super.key, required this.farmId});

  final int farmId;

  @override
  ConsumerState<FieldForm> createState() => _FieldFormState();
}

class _FieldFormState extends ConsumerState<FieldForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _area = TextEditingController();

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
    final input = FieldInput(name: _name.text.trim(), area: parseDecimal(_area.text)!);
    final api = ref.read(farmsApiProvider);
    setState(() {
      _saving = true;
      _fieldErrors = const {};
      _generalErrors = const [];
    });
    try {
      final saved = await api.addField(widget.farmId, input);
      if (!mounted) {
        return;
      }
      ref.invalidate(farmFieldsProvider(widget.farmId));
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
            AppTextField(
              fieldKey: const Key('field-name'),
              controller: _name,
              label: l10n.farmsFormFieldName,
              textCapitalization: TextCapitalization.words,
              maxLength: FarmLimits.nameMaxLength * 2,
              enabled: !_saving,
              validator: nameValidator(l10n),
              serverError: _fieldErrors['name'],
              onChanged: (_) => _clearError('name'),
            ),
            const SizedBox(height: Gaps.md),
            AppTextField(
              fieldKey: const Key('field-area'),
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
              key: const Key('field-submit'),
              label: l10n.farmsDetailAddField,
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
