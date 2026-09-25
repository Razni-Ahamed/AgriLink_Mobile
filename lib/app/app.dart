import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/application/notification_presenter.dart';
import '../l10n/l10n.dart';
import '../l10n/locale_controller.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';

class AgriLinkApp extends ConsumerStatefulWidget {
  const AgriLinkApp({super.key});

  @override
  ConsumerState<AgriLinkApp> createState() => _AgriLinkAppState();
}

class _AgriLinkAppState extends ConsumerState<AgriLinkApp> {
  @override
  void initState() {
    super.initState();
    // Tapping a notification pop-up (or its "View" button) opens the notifications list.
    ref.read(notificationPresenterProvider).onOpen = () =>
        ref.read(routerProvider).go(AppRoutes.notifications);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.commonAppName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(languageProvider).locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
