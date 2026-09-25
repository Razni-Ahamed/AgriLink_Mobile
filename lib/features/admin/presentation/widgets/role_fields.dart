import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/api/api_error_parser.dart';
import '../../../../core/validation/validators.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../application/admin_providers.dart';

/// The department an officer belongs to, chosen from the departments the admin manages. Shows
/// a retry if they can't be loaded, and says so when there are none yet (an officer can't be
/// created without one).
class DepartmentField extends ConsumerWidget {
  const DepartmentField({super.key, required this.value, required this.onChanged, this.fieldKey});

  final int? value;
  final ValueChanged<int?> onChanged;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final departments = ref.watch(departmentsProvider);
    return departments.when(
      loading: () => AppDropdownField<int>(
        label: l10n.commonFieldsDepartment,
        hint: l10n.commonActionsLoading,
        items: const {},
        enabled: false,
        onChanged: (_) {},
      ),
      error: (error, _) => Row(
        children: [
          Expanded(
            child: Text(describeError(error, l10n), style: TextStyle(color: context.colors.danger)),
          ),
          IconButton(
            tooltip: l10n.commonActionsRetry,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(departmentsProvider),
          ),
        ],
      ),
      data: (list) {
        if (list.isEmpty) {
          return Text(
            l10n.ordersDepartmentsNoneYetForCreateUser,
            style: TextStyle(color: context.colors.danger),
          );
        }
        return AppDropdownField<int>(
          key: fieldKey,
          label: l10n.commonFieldsDepartment,
          hint: l10n.ordersDepartmentsSelectDepartment,
          value: list.any((d) => d.departmentId == value) ? value : null,
          items: {for (final d in list) d.departmentId: d.name},
          onChanged: onChanged,
          validator: (id) => id == null ? l10n.commonValidationDepartmentRequiredOfficer : null,
        );
      },
    );
  }
}

/// A buyer's business name, required when making someone a buyer.
class BusinessNameField extends StatelessWidget {
  const BusinessNameField({super.key, required this.controller, this.fieldKey});

  final TextEditingController controller;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final v = FormValidators(l10n);
    return AppTextField(
      fieldKey: fieldKey,
      controller: controller,
      label: l10n.commonFieldsBusinessName,
      textCapitalization: TextCapitalization.words,
      maxLength: FieldLimits.businessName,
      validator: v.all([
        v.required(l10n.commonValidationBusinessNameRequiredBuyer),
        v.maxLength(FieldLimits.businessName, l10n.commonValidationNameTooLong),
      ]),
    );
  }
}
