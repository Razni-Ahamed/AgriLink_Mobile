import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../data/advisory.dart';
import 'authenticated_image.dart';

/// The photos a farmer attached to an issue, with a heading. Tap one to see it full screen and
/// zoom in. Shows nothing when there are none.
class IssuePhotoGallery extends StatelessWidget {
  const IssuePhotoGallery({super.key, required this.photos});

  final List<IssuePhoto> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.issuesAdvisoryPhotos,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.textSecondary),
          ),
        ),
        const SizedBox(height: Gaps.sm),
        for (final photo in photos)
          Padding(
            padding: const EdgeInsets.only(bottom: Gaps.sm),
            // The photo's own shape, but never taller than 60% of the screen, so a portrait photo
            // doesn't push everything else out of view.
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
                child: AspectRatio(
                  aspectRatio: _ratio(photo),
                  child: Semantics(
                    button: true,
                    label: l10n.issuesAdvisoryEnlargePhoto,
                    child: InkWell(
                      key: Key('photo-${photo.imageId}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _open(context, photo),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.tint(colors.textSecondary),
                            border: Border.all(color: colors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AuthenticatedImage(url: photo.url),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static double _ratio(IssuePhoto photo) {
    if (photo.width <= 0 || photo.height <= 0) {
      return 4 / 3;
    }
    return (photo.width / photo.height).clamp(0.6, 2.0);
  }

  void _open(BuildContext context, IssuePhoto photo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => _PhotoViewer(photo: photo)),
    );
  }
}

/// One photo on a black page that can be pinched and dragged.
class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo});

  final IssuePhoto photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: context.l10n.commonActionsClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: InteractiveViewer(
          key: const Key('photo-viewer'),
          maxScale: 6,
          child: Center(
            child: AuthenticatedImage(url: photo.url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
