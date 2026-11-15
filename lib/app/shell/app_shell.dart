import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../features/notifications/application/notification_permission.dart';
import '../../l10n/l10n.dart';
import '../../shared/canopy/glass.dart';
import '../../shared/canopy/motion.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import 'nav_config.dart';

/// Wraps every signed-in page with the role's bottom navigation bar. Pages draw their own
/// app bar (`AgriLinkAppBar`), so a detail page can have a back button and its own title.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// The current path, to highlight the right tab.
  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Timer? _permissionTimer;

  @override
  void initState() {
    super.initState();
    // Once the user has reached their home, and it has had a moment to load, ask (once ever)
    // whether notification pop-ups may be shown.
    _permissionTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        unawaited(askForNotificationPermissionOnce(context, ref));
      }
    });
  }

  @override
  void dispose() {
    _permissionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final location = widget.location;
    final role = ref.watch(sessionControllerProvider.select((s) => s.role));
    if (role == null) {
      return child; // Signing out: the router is about to leave the shell.
    }
    final navigation = navigationFor(role);
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNav(
        navigation: navigation,
        selectedIndex: selectedTabIndex(navigation, location),
        onSelected: (path) => context.go(path),
      ),
    );
  }
}

/// Which tab [location] belongs to: one of the tabs, "More" (the last index) for a section
/// listed under More, or -1 for pages outside the tabs such as the profile.
int selectedTabIndex(RoleNavigation navigation, String location) {
  if (location == AppRoutes.more) {
    return navigation.hasMore ? navigation.tabs.length : -1;
  }
  // The most specific section wins: /admin/users is Users, not the /admin dashboard.
  NavDestination? best;
  for (final destination in navigation.all) {
    if (destination.contains(location) &&
        (best == null || destination.path.length > best.path.length)) {
      best = destination;
    }
  }
  if (best == null) {
    return -1;
  }
  final tab = navigation.tabs.indexOf(best);
  return tab != -1 ? tab : navigation.tabs.length;
}

/// The bottom bar: a floating glass pill with one highlight that slides to the selected tab with
/// a springy, water-like motion. Built by hand rather than with `NavigationBar` so long Sinhala
/// and Tamil labels wrap onto two lines instead of being cut off, and grow with the system font
/// size.
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({
    super.key,
    required this.navigation,
    required this.selectedIndex,
    required this.onSelected,
  });

  final RoleNavigation navigation;
  final int selectedIndex;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final level = motionLevel(context, ref);
    final items = [...navigation.tabs, if (navigation.hasMore) Destinations.more];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.all(5),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  if (selectedIndex >= 0 && selectedIndex < items.length)
                    AnimatedPositioned(
                      duration: Motion.of(level, Motion.reveal),
                      curve: Motion.springy,
                      left: itemWidth * selectedIndex,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.forest.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(22),
                          border: Border(
                            top: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavItem(
                            key: Key('nav-${items[i].path}'),
                            destination: items[i],
                            label: items[i].tabLabel(l10n),
                            selected: i == selectedIndex,
                            onTap: () => onSelected(items[i].path),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.destination,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.forest : colors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The sliding highlight behind the tabs marks the selected one; the icon just
                  // grows a little.
                  AnimatedScale(
                    scale: selected ? 1.1 : 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Motion.springy,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Icon(
                        selected ? destination.selectedIcon : destination.icon,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      height: 1.2,
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
