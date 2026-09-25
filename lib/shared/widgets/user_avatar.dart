import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme/app_colors.dart';
import '../../core/session/role.dart';

/// Only https photo URLs are shown (plain http only for a backend on this PC or emulator), as on
/// the website. Photo URLs are stored data, so nothing else is trusted.
String? safePhotoUrl(String? url) {
  if (url == null || url.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasAuthority) {
    return null;
  }
  if (uri.scheme == 'https') {
    return url;
  }
  const localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};
  return uri.scheme == 'http' && localHosts.contains(uri.host) ? url : null;
}

/// A person's photo, or their role's default picture when they have none or it fails to load.
/// Used in the app bar, the profile, and later in orders and the admin screens.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.role,
    required this.name,
    this.photoUrl,
    this.size = 40,
  });

  final Role role;

  /// The person's name, read out by screen readers.
  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = safePhotoUrl(photoUrl);
    final fallback = _DefaultAvatar(role: role, size: size);
    return Semantics(
      label: name,
      image: true,
      child: ExcludeSemantics(
        child: url == null
            ? fallback
            : ClipOval(
                child: Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
                ),
              ),
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar({required this.role, required this.size});

  final Role role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = switch (role) {
      Role.farmer => colors.forest,
      Role.buyer => colors.terracotta,
      Role.officer => colors.info,
      Role.admin => colors.textPrimary,
    };
    return SvgPicture.asset(
      'assets/icons/avatars/${role.name}.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tone, BlendMode.srcIn),
    );
  }
}
