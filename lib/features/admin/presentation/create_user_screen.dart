import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../core/session/role.dart';
import '../../../core/validation/validators.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../../shared/widgets/district_picker.dart';
import '../../../shared/widgets/form_fields.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';
import '../data/admin_models.dart';
import 'widgets/role_fields.dart';

/// Creates an Officer or Buyer account (farmers register themselves, and admins aren't made
/// here). An officer needs a department, a buyer a business name, and the password follows the
/// same rules as registration. Afterwards the new account's details are shown.
class CreateUserScreen extends ConsumerStatefulWidget {
  const CreateUserScreen({super.key});

  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _businessName = TextEditingController();

  Role _role = Role.officer;
  String? _district;
  int? _departmentId;

  bool _saving = false;
  List<String> _errors = const [];
  CreatedUser? _created;

  @override
  void dispose() {
    for (final controller in [_fullName, _email, _username, _password, _confirm, _businessName]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startAnother() {
    for (final controller in [_fullName, _email, _username, _password, _confirm, _businessName]) {
      controller.clear();
    }
    setState(() {
      _created = null;
      _role = Role.officer;
      _district = null;
      _departmentId = null;
      _errors = const [];
    });
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    // The department dropdown only validates while there are departments to pick from; an
    // officer still can't be created without one.
    final missingDepartment = _role == Role.officer && _departmentId == null;
    if (!_formKey.currentState!.validate() || missingDepartment) {
      setState(
        () => _errors = missingDepartment
            ? [l10n.commonValidationDepartmentRequiredOfficer]
            : const [],
      );
      return;
    }
    setState(() {
      _saving = true;
      _errors = const [];
    });
    try {
      final username = normalizeUsername(_username.text);
      final created = await ref
          .read(adminApiProvider)
          .createUser(
            CreateUserRequest(
              fullName: _fullName.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
              role: _role,
              district: _district!,
              username: username.isEmpty ? null : username,
              departmentId: _departmentId,
              businessName: _role == Role.buyer ? _businessName.text.trim() : null,
            ),
          );
      ref.invalidate(adminUsersProvider);
      if (!mounted) {
        return;
      }
      // The password isn't needed any more; don't keep it in the fields.
      _password.clear();
      _confirm.clear();
      setState(() {
        _saving = false;
        _created = created;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final parsed = parseApiError(
        error,
        context.l10n,
        generic: (l) => l.ordersAdminCreateUserError,
      );
      setState(() {
        _saving = false;
        _errors = [...parsed.generalErrors, ...parsed.fieldErrors.values];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final created = _created;
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.ordersAdminCreateUser),
      body: created != null ? _Created(created: created, onAnother: _startAnother) : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final l10n = context.l10n;
    final v = FormValidators(l10n);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Gaps.md),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.ordersAdminUsersSubtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: Gaps.md),
            AppTextField(
              fieldKey: const Key('create-full-name'),
              controller: _fullName,
              label: l10n.commonFieldsFullName,
              textCapitalization: TextCapitalization.words,
              maxLength: FieldLimits.fullName,
              validator: v.fullName(),
            ),
            const SizedBox(height: Gaps.md),
            AppTextField(
              fieldKey: const Key('create-email'),
              controller: _email,
              label: l10n.commonFieldsEmail,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              maxLength: FieldLimits.email,
              validator: v.email(),
            ),
            const SizedBox(height: Gaps.md),
            AppTextField(
              fieldKey: const Key('create-username'),
              controller: _username,
              label: l10n.commonFieldsUsernameOptional,
              helper: l10n.ordersAdminUsernameHint,
              autocorrect: false,
              // Left blank, the server makes one from the full name.
              validator: (value) => (value ?? '').trim().isEmpty ? null : v.username()(value),
            ),
            const SizedBox(height: Gaps.md),
            PasswordField(
              fieldKey: const Key('create-password'),
              controller: _password,
              label: l10n.commonFieldsPassword,
              isNewPassword: true,
              validator: v.newPassword(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Gaps.sm),
            PasswordChecklist(password: _password.text),
            const SizedBox(height: Gaps.md),
            PasswordField(
              fieldKey: const Key('create-confirm'),
              controller: _confirm,
              label: l10n.commonFieldsConfirmPassword,
              isNewPassword: true,
              validator: v.confirmPassword(() => _password.text),
            ),
            const SizedBox(height: Gaps.md),
            SegmentedButton<Role>(
              key: const Key('create-role'),
              segments: [
                ButtonSegment(
                  value: Role.officer,
                  label: Text(roleLabel(l10n, Role.officer.apiName)),
                ),
                ButtonSegment(value: Role.buyer, label: Text(roleLabel(l10n, Role.buyer.apiName))),
              ],
              selected: {_role},
              onSelectionChanged: (selection) => setState(() {
                _role = selection.first;
                _errors = const [];
              }),
            ),
            const SizedBox(height: Gaps.md),
            DistrictPicker(
              value: _district,
              onChanged: (district) => setState(() => _district = district),
              validator: (value) =>
                  (value ?? '').isEmpty ? l10n.commonValidationDistrictRequired : null,
            ),
            const SizedBox(height: Gaps.md),
            if (_role == Role.officer)
              DepartmentField(
                fieldKey: const Key('create-department'),
                value: _departmentId,
                onChanged: (id) => setState(() => _departmentId = id),
              )
            else
              BusinessNameField(
                fieldKey: const Key('create-business-name'),
                controller: _businessName,
              ),
            const SizedBox(height: Gaps.md),
            if (_errors.isNotEmpty) ...[
              ErrorBanner(messages: _errors),
              const SizedBox(height: Gaps.md),
            ],
            LoadingButton(
              key: const Key('create-submit'),
              label: l10n.ordersAdminCreateUser,
              loadingLabel: l10n.ordersAdminCreating,
              loading: _saving,
              onPressed: _create,
            ),
          ],
        ),
      ),
    );
  }
}

/// The account that was just made. The password is not shown: the admin typed it, and it isn't
/// kept anywhere.
class _Created extends StatelessWidget {
  const _Created({required this.created, required this.onAnother});

  final CreatedUser created;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    Widget row(String label, String value, {Key? key}) => Padding(
      padding: const EdgeInsets.only(bottom: Gaps.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium?.copyWith(color: colors.textSecondary)),
          Text(value, key: key, style: textTheme.bodyLarge),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        InfoBanner(
          success: true,
          title: l10n.adminUsersCreatedTitle,
          message: l10n.ordersAdminUserCreatedWithUsername(
            created.fullName,
            roleLabel(l10n, created.role.apiName),
            created.username,
          ),
        ),
        const SizedBox(height: Gaps.md),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(Gaps.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row(l10n.commonFieldsFullName, created.fullName),
                row(l10n.commonFieldsEmail, created.email),
                row(
                  l10n.commonFieldsUsername,
                  created.username,
                  key: const Key('created-username'),
                ),
                row(l10n.commonFieldsRole, roleLabel(l10n, created.role.apiName)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gaps.md),
        Text(l10n.adminUsersCreatedPasswordNote, style: textTheme.bodySmall),
        const SizedBox(height: Gaps.md),
        FilledButton(
          key: const Key('created-back'),
          onPressed: () => context.go(AppRoutes.adminUsers),
          child: Text(l10n.adminUsersCreatedBackToUsers),
        ),
        const SizedBox(height: Gaps.sm),
        OutlinedButton(
          key: const Key('created-another'),
          onPressed: onAnother,
          child: Text(l10n.adminUsersCreatedAnother),
        ),
      ],
    );
  }
}
