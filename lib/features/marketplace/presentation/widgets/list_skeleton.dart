import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/l10n.dart';

/// Grey placeholder cards while a list loads, like the website's skeletons. The first load can
/// take a while when the API is waking up, and this shows the shape of what's coming.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 4, this.height = 168});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.border;
    return Semantics(
      label: context.l10n.commonActionsLoading,
      child: ListView.separated(
        key: const Key('list-skeleton'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Gaps.md),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: Gaps.sm + 4),
        itemBuilder: (_, _) => ExcludeSemantics(
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(kRadius),
            ),
          ),
        ),
      ),
    );
  }
}
