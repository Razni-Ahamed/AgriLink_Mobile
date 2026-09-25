import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';

/// A list split into one section per status, in [order], with a heading and count for each
/// section that has anything in it. Used for requests, so pending ones come first.
class GroupedByStatus<I, S> extends StatelessWidget {
  const GroupedByStatus({
    super.key,
    required this.items,
    required this.order,
    required this.statusOf,
    required this.labelOf,
    required this.itemBuilder,
  });

  final List<I> items;
  final List<S> order;
  final S Function(I item) statusOf;
  final String Function(S status) labelOf;
  final Widget Function(BuildContext context, I item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, Gaps.lg),
      children: [
        for (final status in order)
          if (items.any((item) => statusOf(item) == status)) ...[
            Padding(
              padding: const EdgeInsets.only(top: Gaps.md, bottom: Gaps.sm),
              child: Semantics(
                header: true,
                child: Text(
                  '${labelOf(status)} (${items.where((item) => statusOf(item) == status).length})',
                  style: text.titleSmall?.copyWith(color: context.colors.textSecondary),
                ),
              ),
            ),
            for (final item in items.where((item) => statusOf(item) == status))
              Padding(
                padding: const EdgeInsets.only(bottom: Gaps.sm + 4),
                child: itemBuilder(context, item),
              ),
          ],
      ],
    );
  }
}
