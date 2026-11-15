import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'glass.dart';
import 'motion.dart';

/// The top of a page: a real photo with the page's title over it, and optionally a glass strip
/// (counts, the weather) floating on the photo. The text sits on a dark scrim, so it stays white
/// and readable whatever the photo and theme. The photo settles in with a slow zoom once.
/// The website's `PhotoBanner`.
class PhotoBanner extends ConsumerWidget {
  const PhotoBanner({
    super.key,
    required this.photo,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.action,
    this.child,
    this.alignment = Alignment.center,
    this.compact = false,
  });

  /// An asset path (see `crop_photos.dart`).
  final String photo;
  final String title;
  final String? eyebrow;
  final String? subtitle;

  /// A button under the title.
  final Widget? action;

  /// A glass strip along the bottom of the banner.
  final Widget? child;

  /// Which part of the photo stays in frame when cropped.
  final Alignment alignment;

  /// Smaller title and padding for working pages (lists).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = motionLevel(context, ref);
    final textTheme = Theme.of(context).textTheme;
    const white = Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: level == MotionLevel.full ? 1.08 : 1, end: 1),
              duration: Motion.of(level, const Duration(milliseconds: 1600)),
              curve: Motion.out,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Image.asset(photo, fit: BoxFit.cover, alignment: alignment),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xDB04100B), Color(0x9904100B), Color(0x2E04100B)],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, compact ? 20 : 26, 20, child == null ? 22 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    style: textTheme.bodySmall?.copyWith(color: white.withValues(alpha: 0.78)),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  title,
                  style: (compact ? textTheme.headlineSmall : textTheme.headlineMedium)?.copyWith(
                    color: white,
                    height: 1.08,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: textTheme.bodyMedium?.copyWith(color: white.withValues(alpha: 0.82)),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 14), action!],
                if (child != null) ...[const SizedBox(height: 16), child!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark glass strip that floats on a banner's photo.
class BannerGlass extends StatelessWidget {
  const BannerGlass({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: IconTheme.merge(
        data: const IconThemeData(color: Colors.white),
        child: GlassSurface(onPhoto: true, padding: padding, child: child),
      ),
    );
  }
}
