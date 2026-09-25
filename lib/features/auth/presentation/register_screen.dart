import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../core/session/role.dart';
import '../../../core/validation/validators.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/district_picker.dart';
import '../../../shared/widgets/form_fields.dart';
import '../application/username_availability.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import 'widgets/auth_layout.dart';
import 'widgets/username_availability_hint.dart';

/// Farmer or buyer self-registration, with the same fields and rules as the website. A
/// successful registration creates a pending account and shows the "waiting for approval"
/// screen; it does not sign in.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.initialRole = Role.farmer});

  final Role initialRole;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late Role _role = widget.initialRole == Role.buyer ? Role.buyer : Role.farmer;

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _nic = TextEditingController();
  final _fieldPlotNumber = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _legalBusinessName = TextEditingController();
  final _businessRegistrationNumber = TextEditingController();
  final _businessPhone = TextEditingController();
  String? _district;

  late final UsernameAvailabilityChecker _usernameCheck;

  bool _submitting = false;
  Map<String, String> _fieldErrors = {};
  List<String> _generalErrors = [];

  @override
  void initState() {
    super.initState();
    _usernameCheck = UsernameAvailabilityChecker(ref.read(authApiProvider));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _email,
      _username,
      _password,
      _confirmPassword,
      _nic,
      _fieldPlotNumber,
      _phoneNumber,
      _legalBusinessName,
      _businessRegistrationNumber,
      _businessPhone,
    ]) {
      controller.dispose();
    }
    _usernameCheck.dispose();
    super.dispose();
  }

  /// Clears a server error once the user edits that field.
  void _edited(String field) {
    if (_fieldErrors.containsKey(field)) {
      setState(() => _fieldErrors = {..._fieldErrors}..remove(field));
    }
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    setState(() {
      _generalErrors = [];
      _fieldErrors = {};
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // The live check already knows; the server would refuse it with a 409 anyway.
    if (_usernameCheck.value == UsernameStatus.taken) {
      setState(() => _fieldErrors = {'username': l10n.commonValidationUsernameTaken});
      return;
    }
    FocusScope.of(context).unfocus();

    final RegisterRequest request = _role == Role.farmer
        ? FarmerRegisterRequest(
            fullName: _fullName.text.trim(),
            email: _email.text.trim(),
            username: normalizeUsername(_username.text),
            password: _password.text,
            nic: normalizeNic(_nic.text),
            district: _district!,
            fieldPlotNumber: _fieldPlotNumber.text.trim(),
            phoneNumber: normalizePhone(_phoneNumber.text),
          )
        : BuyerRegisterRequest(
            fullName: _fullName.text.trim(),
            email: _email.text.trim(),
            username: normalizeUsername(_username.text),
            password: _password.text,
            nic: normalizeNic(_nic.text),
            district: _district!,
            legalBusinessName: _legalBusinessName.text.trim(),
            businessRegistrationNumber: _businessRegistrationNumber.text.trim(),
            businessPhone: normalizePhone(_businessPhone.text),
          );

    setState(() => _submitting = true);
    try {
      await ref.read(authApiProvider).register(request);
      if (mounted) {
        TextInput.finishAutofillContext();
        context.go(AppRoutes.registerPending);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final parsed = parseApiError(error, l10n);
      setState(() {
        _fieldErrors = parsed.fieldErrors;
        _generalErrors = parsed.generalErrors;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final v = FormValidators(l10n);
    const gap = SizedBox(height: Gaps.md);

    return AuthLayout(
      title: l10n.authRegisterTitle,
      subtitle: l10n.authRegisterSubtitle,
      onBack: () => context.go(AppRoutes.login),
      child: AutofillGroup(
        // Offer to save the password only after it worked (see the success path), never
        // just because the screen closed after a failed attempt.
        onDisposeAction: AutofillContextAction.cancel,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<Role>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: Role.farmer,
                    label: Text(l10n.authRegisterRoleFarmer),
                    icon: const Icon(Icons.agriculture_outlined),
                  ),
                  ButtonSegment(
                    value: Role.buyer,
                    label: Text(l10n.authRegisterRoleBuyer),
                    icon: const Icon(Icons.storefront_outlined),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (selection) => setState(() => _role = selection.first),
              ),
              const SizedBox(height: Gaps.lg),
              AppTextField(
                fieldKey: const Key('register-fullName'),
                controller: _fullName,
                label: l10n.commonFieldsFullName,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                validator: v.fullName(),
                serverError: _fieldErrors['fullName'],
                onChanged: (_) => _edited('fullName'),
              ),
              gap,
              AppTextField(
                fieldKey: const Key('register-email'),
                controller: _email,
                label: l10n.commonFieldsEmail,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                validator: v.email(),
                serverError: _fieldErrors['email'],
                onChanged: (_) => _edited('email'),
              ),
              gap,
              AppTextField(
                fieldKey: const Key('register-username'),
                controller: _username,
                label: l10n.commonFieldsUsername,
                autocorrect: false,
                autofillHints: const [AutofillHints.newUsername],
                maxLength: 64,
                validator: v.username(),
                serverError: _fieldErrors['username'],
                onChanged: (value) {
                  _edited('username');
                  _usernameCheck.update(value);
                },
              ),
              ValueListenableBuilder(
                valueListenable: _usernameCheck,
                builder: (context, status, _) => UsernameAvailabilityHint(status: status),
              ),
              gap,
              PasswordField(
                fieldKey: const Key('register-password'),
                controller: _password,
                label: l10n.commonFieldsPassword,
                isNewPassword: true,
                validator: v.newPassword(),
                serverError: _fieldErrors['password'],
                onChanged: (_) => _edited('password'),
              ),
              const SizedBox(height: Gaps.sm),
              PasswordChecklist(password: _password.text),
              gap,
              PasswordField(
                fieldKey: const Key('register-confirmPassword'),
                controller: _confirmPassword,
                label: l10n.commonFieldsConfirmPassword,
                isNewPassword: true,
                validator: v.confirmPassword(() => _password.text),
              ),
              gap,
              AppTextField(
                fieldKey: const Key('register-nic'),
                controller: _nic,
                label: l10n.commonFieldsNic,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                validator: v.nic(),
                serverError: _fieldErrors['nic'],
                onChanged: (_) => _edited('nic'),
              ),
              gap,
              DistrictPicker(
                value: _district,
                validator: (value) => value == null ? l10n.commonValidationDistrictRequired : null,
                serverError: _fieldErrors['district'],
                onChanged: (value) {
                  _edited('district');
                  setState(() => _district = value);
                },
              ),
              gap,
              if (_role == Role.farmer) ...[
                AppTextField(
                  fieldKey: const Key('register-fieldPlotNumber'),
                  controller: _fieldPlotNumber,
                  label: l10n.commonFieldsFieldPlotNumber,
                  validator: v.all([
                    v.required(l10n.commonValidationFieldPlotNumberRequired),
                    v.maxLength(
                      FieldLimits.fieldPlotNumber,
                      l10n.commonValidationFieldPlotNumberTooLong,
                    ),
                  ]),
                  serverError: _fieldErrors['fieldPlotNumber'],
                  onChanged: (_) => _edited('fieldPlotNumber'),
                ),
                gap,
                AppTextField(
                  fieldKey: const Key('register-phoneNumber'),
                  controller: _phoneNumber,
                  label: l10n.commonFieldsPhoneNumber,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  textInputAction: TextInputAction.done,
                  validator: v.phone(
                    requiredMessage: l10n.commonValidationPhoneNumberRequired,
                    invalidMessage: l10n.commonValidationPhoneNumberInvalid,
                  ),
                  serverError: _fieldErrors['phoneNumber'],
                  onChanged: (_) => _edited('phoneNumber'),
                ),
              ] else ...[
                AppTextField(
                  fieldKey: const Key('register-legalBusinessName'),
                  controller: _legalBusinessName,
                  label: l10n.commonFieldsLegalBusinessName,
                  textCapitalization: TextCapitalization.words,
                  validator: v.all([
                    v.required(l10n.commonValidationLegalBusinessNameRequired),
                    v.maxLength(
                      FieldLimits.legalBusinessName,
                      l10n.commonValidationLegalBusinessNameTooLong,
                    ),
                  ]),
                  serverError: _fieldErrors['legalBusinessName'],
                  onChanged: (_) => _edited('legalBusinessName'),
                ),
                gap,
                AppTextField(
                  fieldKey: const Key('register-businessRegistrationNumber'),
                  controller: _businessRegistrationNumber,
                  label: l10n.commonFieldsBusinessRegistrationNumber,
                  autocorrect: false,
                  validator: v.all([
                    v.required(l10n.commonValidationBusinessRegistrationNumberRequired),
                    v.maxLength(
                      FieldLimits.businessRegistrationNumber,
                      l10n.commonValidationBusinessRegistrationNumberTooLong,
                    ),
                  ]),
                  serverError: _fieldErrors['businessRegistrationNumber'],
                  onChanged: (_) => _edited('businessRegistrationNumber'),
                ),
                gap,
                AppTextField(
                  fieldKey: const Key('register-businessPhone'),
                  controller: _businessPhone,
                  label: l10n.commonFieldsBusinessPhone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  validator: v.phone(
                    requiredMessage: l10n.commonValidationBusinessPhoneRequired,
                    invalidMessage: l10n.commonValidationBusinessPhoneInvalid,
                  ),
                  serverError: _fieldErrors['businessPhone'],
                  onChanged: (_) => _edited('businessPhone'),
                ),
              ],
              if (_generalErrors.isNotEmpty) ...[gap, ErrorBanner(messages: _generalErrors)],
              const SizedBox(height: Gaps.lg),
              LoadingButton(
                key: const Key('register-submit'),
                label: l10n.authRegisterSubmit,
                loadingLabel: l10n.authRegisterSubmitting,
                loading: _submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: Gaps.md),
              AuthSwitchLink(
                prompt: l10n.authRegisterHaveAccount,
                linkLabel: l10n.authRegisterLoginLink,
                onPressed: () => context.go(AppRoutes.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
