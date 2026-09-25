import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/format/formatters.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/audit_labels.dart';
import '../data/admin_api.dart';
import '../data/admin_models.dart';

/// A record of key actions across the platform, newest first, loading more as you scroll. The
/// website shows this as a wide table; on a phone each entry is a card that opens to show what
/// changed. A row of chips narrows it to one kind of record.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  /// Null shows every kind of record.
  String? _entity;

  late final PagedListController<AuditLogEntry> _entries = PagedListController(
    loadPage: (page) => ref.read(adminApiProvider).auditLogs(entityName: _entity, page: page),
  );

  @override
  void dispose() {
    _entries.dispose();
    super.dispose();
  }

  void _choose(String? entity) {
    if (entity == _entity) {
      return;
    }
    setState(() => _entity = entity);
    _entries.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.ordersAuditLogTitle),
      body: Column(
        children: [
          _EntityFilter(selected: _entity, onChanged: _choose),
          Expanded(
            child: PagedListView<AuditLogEntry>(
              controller: _entries,
              empty: EmptyView(
                icon: Icons.receipt_long_outlined,
                title: l10n.ordersAuditLogEmpty,
                message: l10n.ordersAuditLogSubtitle,
              ),
              itemBuilder: (context, entry, _) =>
                  _EntryCard(key: ValueKey(entry.auditId), entry: entry),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntityFilter extends StatelessWidget {
  const _EntityFilter({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminAuditEntityFilter,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          // One scrolling row, so the filter takes a single line however long the labels are.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  key: const Key('entity-all'),
                  label: Text(l10n.adminUsersFilterAll),
                  selected: selected == null,
                  onSelected: (_) => onChanged(null),
                ),
                for (final name in auditEntityNames) ...[
                  const SizedBox(width: Gaps.sm),
                  ChoiceChip(
                    key: Key('entity-$name'),
                    label: Text(auditEntityLabel(l10n, name)),
                    selected: selected == name,
                    onSelected: (_) => onChanged(name),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One entry: what was done, who did it, when and to which record. An entry with recorded
/// values opens to show them as Before and After; one without has nothing more to show.
class _EntryCard extends ConsumerWidget {
  const _EntryCard({super.key, required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    final record = '${auditEntityLabel(l10n, entry.entityName)} #${entry.entityId}';
    final summary = [
      l10n.adminAuditBy(entry.userName),
      format.dateTime(entry.createdAt),
    ].join(' · ');
    final title = Text(humanizeAuditAction(entry.action), style: textTheme.titleSmall);
    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(record, style: textTheme.bodyMedium),
        Text(summary, style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
      ],
    );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: entry.hasValues
          ? ExpansionTile(
              // The default borders draw a line above and below the open tile.
              shape: const Border(),
              collapsedShape: const Border(),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              childrenPadding: const EdgeInsets.fromLTRB(Gaps.md, 0, Gaps.md, Gaps.md),
              title: title,
              subtitle: subtitle,
              children: [
                _Value(label: l10n.adminAuditBefore, value: entry.oldValue),
                const SizedBox(height: Gaps.sm),
                _Value(label: l10n.adminAuditAfter, value: entry.newValue),
              ],
            )
          : ListTile(title: title, subtitle: subtitle),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final recorded = (value ?? '').isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelMedium?.copyWith(color: colors.textSecondary)),
        // Selectable, so a long value (a rejection reason, say) can be copied.
        recorded
            ? SelectableText(value!, style: textTheme.bodyMedium!.mono)
            : Text(
                l10n.adminAuditNotRecorded,
                style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
      ],
    );
  }
}
