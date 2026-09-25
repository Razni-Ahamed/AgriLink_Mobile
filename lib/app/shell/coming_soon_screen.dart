import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/state_views.dart';

/// The placeholder for a section a later phase builds. Each one is registered in the router
/// under its real path, so the navigation is complete now and a phase only swaps this for its
/// screen (see docs/ARCHITECTURE.md, "Replacing a placeholder").
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyView(
      icon: icon,
      title: l10n.commonComingSoonTitle,
      message: l10n.commonComingSoonMessage,
    );
  }
}
