import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/l10n.dart';

/// Shows a form in a bottom sheet and returns what the form pops with (null if it was closed).
///
/// The sheet can't be swiped away, so a half-finished save is never abandoned; the form itself
/// blocks closing while it saves (`PopScope`).
Future<T?> showFormSheet<T>(BuildContext context, {required String title, required Widget form}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    builder: (context) => _FormSheet(title: title, form: form),
  );
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({required this.title, required this.form});

  final String title;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the form above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.commonActionsClose,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: Gaps.sm),
            form,
          ],
        ),
      ),
    );
  }
}
