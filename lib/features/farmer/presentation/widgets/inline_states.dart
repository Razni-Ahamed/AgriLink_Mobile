import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_error_parser.dart';
import '../../../../l10n/l10n.dart';

/// Shows one part of a page that loads on its own (a farm's fields, a field's crops) inside a
/// list: a spinner, the error with a **Try again** button, or the data. The whole-screen views
/// in `shared/` can't sit inside a list, because they fill the space they are given.
class InlineAsyncView<T> extends StatelessWidget {
  const InlineAsyncView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.data,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) {
    // While reloading, keep showing what is already there.
    if (value.hasValue) {
      return data(value.requireValue);
    }
    if (value.hasError) {
      final l10n = context.l10n;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gaps.md),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: context.colors.danger),
            const SizedBox(height: Gaps.sm),
            Text(
              describeError(value.error!, l10n),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Gaps.sm),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonActionsRetry),
            ),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: Gaps.lg),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
