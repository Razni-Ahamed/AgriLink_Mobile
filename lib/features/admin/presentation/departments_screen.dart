import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../core/format/formatters.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';
import '../data/admin_models.dart';
import 'widgets/sheet_frame.dart';

/// The departments officers are assigned to: add, rename and delete. A department that still
/// has officers can't be deleted, and the server's reason is shown.
class DepartmentsScreen extends ConsumerStatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  ConsumerState<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends ConsumerState<DepartmentsScreen> {
  bool _busy = false;

  /// Reloads the departments, and the users too, whose department names may have changed.
  void _reload() {
    ref.invalidate(departmentsProvider);
    ref.invalidate(adminUsersProvider);
  }

  Future<void> _add() async {
    final created = await showFormSheet<Department>(
      context,
      builder: (_) => const _DepartmentSheet(),
    );
    if (created == null || !mounted) {
      return;
    }
    _reload();
    showToast(
      context,
      context.l10n.ordersDepartmentsCreated(created.name),
      tone: ToastTone.success,
    );
  }

  Future<void> _rename(Department department) async {
    final renamed = await showFormSheet<Department>(
      context,
      builder: (_) => _DepartmentSheet(department: department),
    );
    if (renamed == null || !mounted) {
      return;
    }
    _reload();
    showToast(
      context,
      context.l10n.ordersDepartmentsRenamed(renamed.name),
      tone: ToastTone.success,
    );
  }

  Future<void> _delete(Department department) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.ordersDepartmentsConfirmDeleteTitle,
      message: l10n.ordersDepartmentsConfirmDeleteBody(department.name),
      confirmLabel: l10n.commonActionsDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(adminApiProvider).deleteDepartment(department.departmentId);
      _reload();
      if (mounted) {
        showToast(context, l10n.ordersDepartmentsDeleted(department.name), tone: ToastTone.success);
      }
    } on Object catch (error) {
      // "This department has officers assigned to it…" comes back as the server's own message.
      _reload();
      if (mounted) {
        showToast(context, describeError(error, context.l10n), tone: ToastTone.error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final departments = ref.watch(departmentsProvider);
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.ordersDepartmentsTitle),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-department'),
        onPressed: _busy ? null : _add,
        icon: const Icon(Icons.add),
        label: Text(l10n.ordersDepartmentsNewDepartment),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(departmentsProvider);
          try {
            await ref.read(departmentsProvider.future);
          } on Object {
            // The list shows the error itself; the spinner only has to stop.
          }
        },
        child: AsyncValueView<List<Department>>(
          value: departments,
          onRetry: () => ref.invalidate(departmentsProvider),
          data: (list) => list.isEmpty
              ? EmptyView(icon: Icons.apartment_outlined, title: l10n.ordersDepartmentsEmpty)
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Room under the last card for the add button.
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  children: [
                    Text(
                      l10n.ordersDepartmentsSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: Gaps.md),
                    for (final department in list) ...[
                      _DepartmentCard(
                        key: ValueKey(department.departmentId),
                        department: department,
                        busy: _busy,
                        onRename: () => _rename(department),
                        onDelete: () => _delete(department),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _DepartmentCard extends ConsumerWidget {
  const _DepartmentCard({
    super.key,
    required this.department,
    required this.busy,
    required this.onRename,
    required this.onDelete,
  });

  final Department department;
  final bool busy;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.sm, Gaps.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(department.name, style: textTheme.titleMedium),
                  Text(
                    '${l10n.ordersDepartmentsCreatedOn} ${format.date(department.createdAt)}',
                    style: textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('rename-${department.departmentId}'),
              tooltip: '${l10n.ordersDepartmentsRename}: ${department.name}',
              icon: const Icon(Icons.edit_outlined),
              onPressed: busy ? null : onRename,
            ),
            IconButton(
              key: Key('delete-${department.departmentId}'),
              tooltip: '${l10n.commonActionsDelete}: ${department.name}',
              icon: Icon(Icons.delete_outline, color: busy ? null : context.colors.danger),
              onPressed: busy ? null : onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Adds a department, or renames [department]. Closes with the saved [Department].
class _DepartmentSheet extends ConsumerStatefulWidget {
  const _DepartmentSheet({this.department});

  final Department? department;

  @override
  ConsumerState<_DepartmentSheet> createState() => _DepartmentSheetState();
}

class _DepartmentSheetState extends ConsumerState<_DepartmentSheet> {
  static const _maxLength = 100;

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.department?.name);

  bool _saving = false;
  List<String> _errors = const [];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _errors = const [];
    });
    final name = _name.text.trim();
    final api = ref.read(adminApiProvider);
    final existing = widget.department;
    try {
      final saved = existing == null
          ? await api.createDepartment(name)
          : await api.renameDepartment(existing.departmentId, name);
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final parsed = parseApiError(
        error,
        context.l10n,
        generic: (l) => l.ordersDepartmentsSaveError,
        conflict: (l) => l.ordersDepartmentsDuplicateError,
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
    final renaming = widget.department != null;
    return SheetFrame(
      title: renaming ? l10n.ordersDepartmentsRename : l10n.ordersDepartmentsNewDepartment,
      children: [
        Form(
          key: _formKey,
          child: AppTextField(
            fieldKey: const Key('department-name'),
            controller: _name,
            label: l10n.ordersDepartmentsName,
            textCapitalization: TextCapitalization.words,
            maxLength: _maxLength,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _saving ? null : _save(),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l10n.ordersDepartmentsNameRequired : null,
          ),
        ),
        const SizedBox(height: Gaps.md),
        if (_errors.isNotEmpty) ...[
          ErrorBanner(messages: _errors),
          const SizedBox(height: Gaps.md),
        ],
        LoadingButton(
          key: const Key('department-save'),
          label: renaming ? l10n.ordersDepartmentsSaveChanges : l10n.ordersDepartmentsCreate,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
