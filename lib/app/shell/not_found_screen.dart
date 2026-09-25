import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/state_views.dart';
import '../router/app_routes.dart';

/// For a link to a page that doesn't exist.
class NotFoundScreen extends ConsumerWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final role = ref.watch(sessionControllerProvider).role;
    return Scaffold(
      body: SafeArea(
        child: EmptyView(
          icon: Icons.explore_off_outlined,
          title: l10n.commonErrorsNotFound,
          action: FilledButton(
            onPressed: () => context.go(role == null ? AppRoutes.login : homePathFor(role)),
            child: Text(l10n.authUnauthorizedBackHome),
          ),
        ),
      ),
    );
  }
}
