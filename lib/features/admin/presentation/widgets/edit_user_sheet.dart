import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_error_parser.dart';
import '../../../../core/session/role.dart';
import '../../../../core/validation/validators.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/district_picker.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../data/admin_api.dart';
import '../../data/admin_models.dart';
import 'sheet_frame.dart';

/// Edits a user's details directly (no approval step, since the admin is the approver). Which
/// fields appear depends on the user's role, as on the website: everyone has a name, email and
/// phone; farmers and buyers a NIC; farmers, buyers and officers a district; buyers business
/// details; farmers a plot.
///
/// Only the name, email and district are known from the users list, so those start filled in.
/// The others start empty and mean "keep what it is now": nothing is ever sent to clear a field.
/// Closes with the updated [AdminUser] once saved.
class EditUserSheet extends ConsumerStatefulWidget {
  const EditUserSheet({super.key, required this.user});

  final AdminUser user;

  @override
  ConsumerState<EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends ConsumerState<EditUserSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _fullName = TextEditingController(text: widget.user.fullName);
  late final _email = TextEditingController(text: widget.user.email);
  final _displayName = TextEditingController();
  final _phone = TextEditingController();
  final _nic = TextEditingController();
  final _businessName = TextEditingController();
  final _businessReg = TextEditingController();
  final _fieldPlot = TextEditingController();
  late String? _district = widget.user.district;

  bool _saving = false;
  bool _nothingToSave = false;
  List<String> _generalErrors = const [];

  Role get _role => widget.user.role;
  bool get _hasNic => _role == Role.farmer || _role == Role.buyer;
  bool get _hasDistrict => _role != Role.admin;
  bool get _isBuyer => _role == Role.buyer;
  bool get _isFarmer => _role == Role.farmer;

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _email,
      _displayName,
      _phone,
      _nic,
      _businessName,
      _businessReg,
      _fieldPlot,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// A field the admin typed into, or null to leave it alone.
  String? _typed(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  UpdateUserProfileRequest _request() {
    final user = widget.user;
    final fullName = _fullName.text.trim();
    final email = _email.text.trim();
    return UpdateUserProfileRequest(
      fullName: fullName.isNotEmpty && fullName != user.fullName ? fullName : null,
      email: email.isNotEmpty && email != user.email ? email : null,
      displayName: _typed(_displayName),
      phoneNumber: _typed(_phone) == null ? null : normalizePhone(_phone.text.trim()),
      nic: _hasNic && _typed(_nic) != null ? normalizeNic(_nic.text) : null,
      district: _hasDistrict && _district != null && _district != user.district ? _district : null,
      businessName: _isBuyer ? _typed(_businessName) : null,
      businessRegistrationNumber: _isBuyer ? _typed(_businessReg) : null,
      fieldPlotNumber: _isFarmer ? _typed(_fieldPlot) : null,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final request = _request();
    if (request.isEmpty) {
      setState(() {
        _nothingToSave = true;
        _generalErrors = const [];
      });
      return;
    }
    setState(() {
      _saving = true;
      _nothingToSave = false;
      _generalErrors = const [];
    });
    try {
      final updated = await ref.read(adminApiProvider).updateProfile(widget.user.userId, request);
      if (mounted) {
        Navigator.of(context).pop(updated);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final parsed = parseApiError(
        error,
        context.l10n,
        generic: (l) => l.ordersAdminEditUserError,
        conflict: (l) => l.ordersAdminEditUserEmailTaken,
      );
      // Everything goes in the banner: an error forced onto a field would keep the form
      // invalid until the widget was rebuilt, and this endpoint mostly answers with one message.
      setState(() {
        _saving = false;
        _generalErrors = [...parsed.generalErrors, ...parsed.fieldErrors.values];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final v = FormValidators(l10n);
    final unchanged = l10n.ordersAdminEditUserUnchanged;
    return SheetFrame(
      title: l10n.ordersAdminEditUserFor(widget.user.fullName),
      children: [
        Text(l10n.ordersAdminEditUserKeepCurrent, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: Gaps.md),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                fieldKey: const Key('edit-full-name'),
                controller: _fullName,
                label: l10n.commonFieldsFullName,
                textCapitalization: TextCapitalization.words,
                maxLength: FieldLimits.fullName,
                validator: v.fullName(),
              ),
              const SizedBox(height: Gaps.md),
              AppTextField(
                fieldKey: const Key('edit-display-name'),
                controller: _displayName,
                label: l10n.ordersAdminEditUserDisplayName,
                hint: unchanged,
                maxLength: FieldLimits.displayName,
                validator: v.maxLength(FieldLimits.displayName, l10n.commonValidationNameTooLong),
              ),
              const SizedBox(height: Gaps.md),
              AppTextField(
                fieldKey: const Key('edit-email'),
                controller: _email,
                label: l10n.commonFieldsEmail,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                maxLength: FieldLimits.email,
                validator: v.email(),
              ),
              const SizedBox(height: Gaps.md),
              AppTextField(
                fieldKey: const Key('edit-phone'),
                controller: _phone,
                label: l10n.commonFieldsPhoneNumber,
                hint: unchanged,
                keyboardType: TextInputType.phone,
                validator: (value) => (value ?? '').trim().isEmpty || isValidPhone(value!)
                    ? null
                    : l10n.commonValidationPhoneNumberInvalid,
              ),
              if (_hasNic) ...[
                const SizedBox(height: Gaps.md),
                AppTextField(
                  fieldKey: const Key('edit-nic'),
                  controller: _nic,
                  label: l10n.commonFieldsNic,
                  hint: unchanged,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) =>
                      (value ?? '').trim().isEmpty || isValidNic(normalizeNic(value!))
                      ? null
                      : l10n.commonValidationNicInvalid,
                ),
              ],
              if (_hasDistrict) ...[
                const SizedBox(height: Gaps.md),
                DistrictPicker(
                  value: _district,
                  onChanged: (district) => setState(() => _district = district),
                ),
              ],
              if (_isBuyer) ...[
                const SizedBox(height: Gaps.md),
                AppTextField(
                  fieldKey: const Key('edit-business-name'),
                  controller: _businessName,
                  label: l10n.commonFieldsBusinessName,
                  hint: unchanged,
                  textCapitalization: TextCapitalization.words,
                  maxLength: FieldLimits.businessName,
                  validator: v.maxLength(
                    FieldLimits.businessName,
                    l10n.commonValidationNameTooLong,
                  ),
                ),
                const SizedBox(height: Gaps.md),
                AppTextField(
                  fieldKey: const Key('edit-business-reg'),
                  controller: _businessReg,
                  label: l10n.commonFieldsBusinessRegistrationNumber,
                  hint: unchanged,
                  maxLength: FieldLimits.businessRegistrationNumber,
                  validator: v.maxLength(
                    FieldLimits.businessRegistrationNumber,
                    l10n.commonValidationBusinessRegistrationNumberTooLong,
                  ),
                ),
              ],
              if (_isFarmer) ...[
                const SizedBox(height: Gaps.md),
                AppTextField(
                  fieldKey: const Key('edit-field-plot'),
                  controller: _fieldPlot,
                  label: l10n.commonFieldsFieldPlotNumber,
                  hint: unchanged,
                  maxLength: FieldLimits.fieldPlotNumber,
                  validator: v.maxLength(
                    FieldLimits.fieldPlotNumber,
                    l10n.commonValidationFieldPlotNumberTooLong,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Gaps.md),
        if (_nothingToSave) InfoBanner(message: l10n.ordersAdminEditUserNoChanges),
        if (_generalErrors.isNotEmpty) ErrorBanner(messages: _generalErrors),
        const SizedBox(height: Gaps.sm),
        LoadingButton(
          key: const Key('edit-save'),
          label: l10n.ordersAdminEditUserSave,
          loadingLabel: l10n.ordersAdminEditUserSaving,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
