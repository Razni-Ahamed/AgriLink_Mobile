import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'agrilink_app_bar.dart';
import 'coming_soon_screen.dart';
import 'nav_config.dart';

/// A whole page for a section that a later phase builds: the app bar with the section's name,
/// and "Coming soon". Replace it in the feature's route file with the real screen.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.destination});

  final NavDestination destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AgriLinkAppBar(title: destination.label(context.l10n)),
      body: ComingSoonScreen(icon: destination.icon),
    );
  }
}
