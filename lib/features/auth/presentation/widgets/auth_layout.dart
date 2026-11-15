import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/canopy/glass.dart';
import '../../../../shared/media/crop_photos.dart';
import '../../../../shared/widgets/language_switcher.dart';
import '../../../../shared/widgets/theme_mode_button.dart';

/// The layout shared by the signed-out screens: a photo of Sri Lankan fields behind, the
/// language and theme choices on glass at the top, the AgriLink name on the photo, then a
/// solid card with a title and the form. Scrolls, so it works on small
/// screens, in landscape and with large system fonts.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Where Android's back button goes (e.g. from registration back to sign-in). Without it,
  /// back leaves the app, which is right for the login screen itself.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final scaffold = Scaffold(
      backgroundColor: const Color(0xFF0B201A),
      body: Stack(
        children: [
          // Sri Lankan fields behind everything, darkened so white text and the card stand out.
          Positioned.fill(
            child: Image.asset(Scenes.fields, fit: BoxFit.cover, alignment: Alignment.topCenter),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x6604100B), Color(0xB304100B), Color(0xEB04100B)],
                  stops: [0, 0.5, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Gaps.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const GlassSurface(
                        padding: EdgeInsets.all(6),
                        child: Row(
                          children: [
                            Expanded(child: LanguageSwitcher()),
                            SizedBox(width: Gaps.sm),
                            ThemeModeButton(),
                          ],
                        ),
                      ),
                      const SizedBox(height: Gaps.xl),
                      // The name on the photo, like the website's sign-in scene.
                      Row(
                        children: [
                          const Icon(Icons.eco, color: Color(0xFFB5CDA0), size: 28),
                          const SizedBox(width: Gaps.sm),
                          Text(
                            context.l10n.commonAppName,
                            style: textTheme.headlineMedium?.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gaps.md),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(Gaps.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  style: textTheme.headlineSmall?.copyWith(color: colors.forest),
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: Gaps.xs),
                                Text(
                                  subtitle!,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colors.textSecondary,
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
        ],
      ),
    );
    final onBack = this.onBack;
    if (onBack == null) {
      return scaffold;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          onBack();
        }
      },
      child: scaffold,
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
