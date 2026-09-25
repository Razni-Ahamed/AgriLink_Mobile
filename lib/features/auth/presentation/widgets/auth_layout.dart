import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/language_switcher.dart';
import '../../../../shared/widgets/theme_mode_button.dart';

/// The layout shared by the signed-out screens: the language and theme choices at the top,
/// then a card with the AgriLink name, a title and the form. Scrolls, so it works on small
/// screens, in landscape and with large system fonts.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gaps.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Expanded(child: LanguageSwitcher()),
                      SizedBox(width: Gaps.sm),
                      ThemeModeButton(),
                    ],
                  ),
                  const SizedBox(height: Gaps.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Gaps.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.eco, color: context.colors.forest),
                              const SizedBox(width: Gaps.sm),
                              Text(
                                context.l10n.commonAppName,
                                style: textTheme.titleMedium?.copyWith(
                                  color: context.colors.forest,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Gaps.sm),
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: textTheme.headlineSmall?.copyWith(
                                color: context.colors.forest,
                              ),
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: Gaps.xs),
                            Text(
                              subtitle!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: Gaps.lg),
                          child,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "No account? Register" style line with a link button.
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.prompt,
    required this.linkLabel,
    required this.onPressed,
  });

  final String prompt;
  final String linkLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.colors.textSecondary),
        ),
        TextButton(onPressed: onPressed, child: Text(linkLabel)),
      ],
    );
  }
}
