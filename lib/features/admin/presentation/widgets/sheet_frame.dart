import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Opens [builder] as a tall bottom sheet that lifts above the keyboard. Every admin form
/// (edit, change role, reset password) uses it; the sheet closes with the form's result.
Future<T?> showFormSheet<T>(BuildContext context, {required WidgetBuilder builder}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: builder,
    );

/// The padding and scrolling every form sheet shares: content scrolls when the keyboard is up,
/// and there's a title at the top.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(Gaps.md, Gaps.md, Gaps.md, Gaps.md + keyboard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Gaps.md),
          ...children,
        ],
      ),
    );
  }
}
