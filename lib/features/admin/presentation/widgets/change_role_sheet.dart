import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_error_parser.dart';
import '../../../../core/session/role.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/dialogs.dart';
import '../../../../shared/widgets/district_picker.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../data/admin_api.dart';
import '../../data/admin_models.dart';
import 'role_fields.dart';
import 'sheet_frame.dart';

/// Turns an officer into a buyer or a buyer into an officer. Only those two can be re-typed,
/// so the new role is simply the other one. An officer needs a district and department, a buyer
/// a district and business name. Asks to confirm, naming the user, then closes with the updated
/// [AdminUser].
class ChangeRoleSheet extends ConsumerStatefulWidget {
  const ChangeRoleSheet({super.key, required this.user});

  final AdminUser user;

  @override
  ConsumerState<ChangeRoleSheet> createState() => _ChangeRoleSheetState();
}

class _ChangeRoleSheetState extends ConsumerState<ChangeRoleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  late String? _district = widget.user.district;
  int? _departmentId;

  bool _saving = false;
  List<String> _errors = const [];

  Role get _newRole => widget.user.role == Role.officer ? Role.buyer : Role.officer;

  @override
  void dispose() {
    _businessName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final user = widget.user;
    // The dropdown only validates while there are departments to pick from; an officer still
    // can't be made without one.
    final missingDepartment = _newRole == Role.officer && _departmentId == null;
    if (!_formKey.currentState!.validate() || missingDepartment) {
      setState(
        () => _errors = missingDepartment
            ? [l10n.commonValidationDepartmentRequiredOfficer]
            : const [],
      );
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.adminUsersDetailRoleConfirmTitle(user.fullName),
      message: l10n.adminUsersDetailRoleConfirmMessage(
        user.fullName,
        roleLabel(l10n, _newRole.apiName),
      ),
      confirmLabel: l10n.ordersAdminUpdateRole,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _saving = true;
      _errors = const [];
    });
    try {
      final updated = await ref
          .read(adminApiProvider)
          .changeRole(
            user.userId,
            ChangeRoleRequest(
              role: _newRole,
              district: _district!,
              departmentId: _departmentId,
              businessName: _businessName.text.trim(),
            ),
          );
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
        generic: (l) => l.ordersAdminRoleUpdateError,
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
    final textTheme = Theme.of(context).textTheme;
    return SheetFrame(
      title: l10n.ordersAdminChangeRole,
      children: [
        Text(l10n.ordersAdminChangeRoleFor(widget.user.fullName), style: textTheme.bodyMedium),
        const SizedBox(height: Gaps.sm),
        // Both roles are written out, so it reads without relying on colour or an arrow icon.
        Text(
          '${roleLabel(l10n, widget.user.role.apiName)} → ${roleLabel(l10n, _newRole.apiName)}',
          key: const Key('role-change'),
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: Gaps.md),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DistrictPicker(
                value: _district,
                onChanged: (district) => setState(() => _district = district),
                validator: (value) =>
                    (value ?? '').isEmpty ? l10n.commonValidationDistrictRequired : null,
              ),
              const SizedBox(height: Gaps.md),
              if (_newRole == Role.officer)
                DepartmentField(
                  fieldKey: const Key('role-department'),
                  value: _departmentId,
                  onChanged: (id) => setState(() => _departmentId = id),
                )
              else
                BusinessNameField(
                  fieldKey: const Key('role-business-name'),
                  controller: _businessName,
                ),
            ],
          ),
        ),
        const SizedBox(height: Gaps.md),
        if (_errors.isNotEmpty) ErrorBanner(messages: _errors),
        const SizedBox(height: Gaps.sm),
        LoadingButton(
          key: const Key('role-save'),
          label: l10n.ordersAdminUpdateRole,
          loadingLabel: l10n.ordersAdminUpdating,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
