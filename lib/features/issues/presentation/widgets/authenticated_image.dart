import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../application/advisories.dart';

/// An issue photo, loaded through the API client because the API only shows it to the signed-in
/// farmer who took it and to officers. A plain `Image.network` would be refused, since it can't
/// send the token.
///
/// While it loads it shows a spinner; if it can't be loaded it says "Photo unavailable" with a
/// **Try again** button instead of leaving a hole.
class AuthenticatedImage extends ConsumerWidget {
  const AuthenticatedImage({super.key, required this.url, this.fit = BoxFit.cover});

  /// The photo's API path, e.g. `/api/issues/7/images/9` ([IssuePhoto.url]).
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref
        .watch(issuePhotoProvider(url))
        .when(
          data: (bytes) => Image.memory(
            bytes,
            fit: fit,
            semanticLabel: l10n.issuesAdvisoryPhotoAlt,
            // A photo the phone can't read is the same problem as one that didn't arrive.
            errorBuilder: (context, error, stack) => const _Unavailable(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              _Unavailable(onRetry: () => ref.invalidate(issuePhotoProvider(url))),
        );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: colors.textSecondary),
            const SizedBox(height: 4),
            Text(
              l10n.issuesAdvisoryPhotoUnavailable,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text(l10n.commonActionsRetry)),
          ],
        ),
      ),
    );
  }
}
