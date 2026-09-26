import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/l10n.dart';

/// A row of chips for narrowing a list by status: "All" then one per status, each with how many
/// items have it. [selected] is null for "All".
class StatusFilterChips<T> extends StatelessWidget {
  const StatusFilterChips({
    super.key,
    required this.statuses,
    required this.counts,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  final List<T> statuses;

  /// How many items have each status; "All" shows the total.
  final Map<T, int> counts;
  final String Function(T status) labelOf;
  final T? selected;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (sum, count) => sum + count);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
      child: Row(
        children: [
          _chip(
            key: const Key('status-all'),
            label: '${context.l10n.marketplaceStatusFilterAll} ($total)',
            isSelected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final status in statuses)
            _chip(
              key: Key('status-$status'),
              label: '${labelOf(status)} (${counts[status] ?? 0})',
              isSelected: selected == status,
              onTap: () => onSelected(status),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(right: Gaps.sm),
    child: ChoiceChip(
      key: key,
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
    ),
  );
}

/// How many of [items] have each status.
Map<T, int> countByStatus<I, T>(Iterable<I> items, T Function(I item) statusOf) {
  final counts = <T, int>{};
  for (final item in items) {
    final status = statusOf(item);
    counts[status] = (counts[status] ?? 0) + 1;
  }
  return counts;
}
