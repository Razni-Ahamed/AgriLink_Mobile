import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../l10n/locale_controller.dart';

/// English / සිංහල / தமிழ். Each option is written in its own language so anyone can find
/// theirs. Used on the login screen and in the profile; the choice is remembered.
class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);
    return Semantics(
      label: context.l10n.commonLanguageLabel,
      container: true,
      child: SegmentedButton<AppLanguage>(
        showSelectedIcon: false,
        segments: [
          for (final language in AppLanguage.values)
            ButtonSegment(
              value: language,
              label: Text(
                language.nativeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        selected: {current},
        onSelectionChanged: (selection) =>
            ref.read(languageProvider.notifier).setLanguage(selection.first),
      ),
    );
  }
}
