import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme_mode_controller.dart';
import '../../l10n/l10n.dart';

/// An icon button that chooses light, dark or the system setting. The choice is remembered.
class ThemeModeButton extends ConsumerWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(themeModeProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: l10n.commonThemeLabel,
      icon: Icon(themeModeIcon(mode)),
      initialValue: mode,
      onSelected: (mode) => ref.read(themeModeProvider.notifier).setMode(mode),
      itemBuilder: (context) => [
        for (final option in ThemeMode.values)
          CheckedPopupMenuItem(
            value: option,
            checked: option == mode,
            child: Text(themeModeLabel(l10n, option)),
          ),
      ],
    );
  }
}

IconData themeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
  ThemeMode.system => Icons.brightness_auto_outlined,
};

String themeModeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
  ThemeMode.light => l10n.commonThemeLight,
  ThemeMode.dark => l10n.commonThemeDark,
  ThemeMode.system => l10n.commonThemeSystem,
};
