import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import 'widgets/auth_layout.dart';

/// After registering: the account exists but can't be used until it is approved.
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthLayout(
      title: l10n.authRegisterPendingTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.hourglass_top, size: 56, color: context.colors.harvest),
          const SizedBox(height: Gaps.md),
          Text(
            l10n.authRegisterPendingMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: Gaps.lg),
          FilledButton(
            onPressed: () => context.go(AppRoutes.login),
            child: Text(l10n.authRegisterBackToLogin),
          ),
        ],
      ),
    );
  }
}
