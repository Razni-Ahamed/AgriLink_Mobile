import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../../shared/canopy/animated_check.dart';
import '../../../shared/canopy/motion.dart';
import '../../../shared/media/crop_photos.dart';
import '../../../shared/media/photo_picker.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/state_views.dart';
import '../../issues/data/crop_issue.dart';
import '../../issues/data/issue_enums.dart';
import '../../issues/data/issues_api.dart';
import '../application/farms.dart';
import '../application/my_issues.dart';
import '../data/crop.dart';
import '../farmer_paths.dart';
import 'widgets/issue_crop_field.dart';

/// The most the API accepts (`CreateCropIssueRequest`).
const _titleMaxLength = 150;
const _descriptionMaxLength = 2000;

/// Reports a problem with one of the farmer's crops, with an optional photo from the camera or
/// gallery. [initialCropId] chooses the crop up front (from a crop's own page).
class ReportIssueScreen extends ConsumerWidget {
  const ReportIssueScreen({super.key, this.initialCropId});

  final int? initialCropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.issuesNewTitle),
      body: AsyncValueView<List<FarmerCrop>>(
        value: ref.watch(myCropsProvider),
        onRetry: () => ref.invalidate(myCropsProvider),
        data: (crops) => crops.isEmpty
            // An issue is always about a crop, so a farmer with none plants one first.
            ? EmptyView(
                icon: Icons.warning_amber_outlined,
                title: l10n.issuesNewNoCrop,
                action: FilledButton(
                  onPressed: () => context.go(AppRoutes.farms),
                  child: Text(l10n.issuesNewGoToFarms),
                ),
              )
            : _ReportForm(crops: crops, initialCropId: initialCropId),
      ),
    );
  }
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({required this.crops, this.initialCropId});

  final List<FarmerCrop> crops;
  final int? initialCropId;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _scroll = ScrollController();

  late int? _cropId = widget.crops.any((crop) => crop.id == widget.initialCropId)
      ? widget.initialCropId
      : null;
  IssueSeverity _severity = IssueSeverity.medium;
  PickedPhoto? _photo;

  bool _pickingPhoto = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    setState(() => _pickingPhoto = true);
    try {
      // Asks for the camera only now, with an explanation, and handles a refusal.
      final photo = await pickPhoto(context, ref);
      if (photo != null && mounted) {
        setState(() => _photo = photo);
      }
    } finally {
      if (mounted) {
        setState(() => _pickingPhoto = false);
      }
    }
  }

  /// What to tell the farmer, like the website's `reportErrorKey`. A photo the server can't use,
  /// or storage being down, is worth saying, since reporting without the photo would work.
  String _messageFor(Object error, {required bool hadPhoto}) {
    final l10n = context.l10n;
    if (error is ApiException) {
      // The analysis takes a while, so a timeout may still have created the issue.
      if (error.kind == ApiErrorKind.timeout) {
        return l10n.issuesNewTimeout;
      }
      if (error.isConnectivity) {
        return l10n.commonErrorsNetwork;
      }
      if (hadPhoto && error.kind == ApiErrorKind.badRequest) {
        return l10n.issuesNewPhotoRejected;
      }
      if (hadPhoto && error.statusCode == 503) {
        return l10n.issuesNewPhotoUploadUnavailable;
      }
    }
    return l10n.issuesNewReportError;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    final request = CreateCropIssueRequest(
      cropId: _cropId!,
      title: _title.text.trim(),
      description: _description.text.trim(),
      severity: _severity,
    );
    final photo = _photo;
    final api = ref.read(issuesApiProvider);
    // Kept now, because the farmer may leave this page while the analysis runs.
    final revision = ref.read(issuesRevisionProvider.notifier);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final issue = photo == null
          ? await api.create(request)
          : await api.createWithPhoto(request, photo);
      revision.bump();
      if (!mounted) {
        return;
      }
      showToast(context, l10n.issuesNewReported, tone: ToastTone.success);
      _openResult(issue);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      // Everything they typed, and the photo, stays as it was.
      final message = _messageFor(error, hadPhoto: photo != null);
      setState(() {
        _submitting = false;
        _error = message;
      });
      showToast(context, message, tone: ToastTone.error);
      // The farmer pressed Send at the bottom; the message is at the top.
      if (_scroll.hasClients) {
        unawaited(
          _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
        );
      }
    }
  }

  /// Straight to the advice when there already is some (a photo the model was sure about);
  /// otherwise to the issue, which says an officer is looking at it.
  void _openResult(CropIssue issue) {
    if (issue.hasReleasedAdvisory) {
      context.go(AppRoutes.myIssues);
      unawaited(context.push<void>(FarmerPaths.advisory(issue.advisoryId!)));
    } else {
      context.go(FarmerPaths.issue(issue.id), extra: issue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final locked = _submitting;
    final photo = _photo;
    return PopScope(
      // Leaving mid-submit would drop the result of a report that is still being analysed.
      canPop: !_submitting,
      child: Stack(
        children: [
          Form(
            key: _formKey,
            // A short form, so everything is built at once (no lazy list to scroll through).
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(Gaps.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    ErrorBanner(messages: [_error!]),
                    const SizedBox(height: Gaps.md),
                  ],
                  IssueCropField(
                    key: const Key('issue-crop'),
                    crops: widget.crops,
                    value: _cropId,
                    enabled: !locked,
                    onChanged: (id) => setState(() => _cropId = id),
                    validator: (id) => id == null ? l10n.issuesNewCropRequired : null,
                  ),
                  const SizedBox(height: Gaps.md),
                  AppTextField(
                    fieldKey: const Key('issue-title'),
                    controller: _title,
                    label: l10n.issuesFormTitle,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: _titleMaxLength,
                    enabled: !locked,
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? l10n.issuesFormTitleRequired : null,
                  ),
                  const SizedBox(height: Gaps.md),
                  AppTextField(
                    fieldKey: const Key('issue-description'),
                    controller: _description,
                    label: l10n.issuesFormDescription,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 5,
                    maxLength: _descriptionMaxLength,
                    enabled: !locked,
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? l10n.issuesFormDescriptionRequired : null,
                  ),
                  const SizedBox(height: Gaps.md),
                  AppDropdownField<IssueSeverity>(
                    key: const Key('issue-severity'),
                    label: l10n.issuesFormSeverity,
                    value: _severity,
                    enabled: !locked,
                    items: {
                      for (final severity in IssueSeverity.values)
                        severity: statusLabel(l10n, StatusKind.severity, severity.apiName),
                    },
                    onChanged: (severity) => setState(() => _severity = severity ?? _severity),
                  ),
                  const SizedBox(height: Gaps.lg),
                  Semantics(
                    header: true,
                    child: Text(l10n.issuesFormPhotoLabel, style: textTheme.titleSmall),
                  ),
                  const SizedBox(height: Gaps.xs),
                  Text(
                    l10n.issuesFormPhotoHint,
                    style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: Gaps.sm),
                  if (photo != null) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          photo.bytes,
                          key: const Key('photo-preview'),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          semanticLabel: l10n.issuesFormPhotoPreviewAlt,
                        ),
                      ),
                    ),
                    const SizedBox(height: Gaps.sm),
                    Wrap(
                      spacing: Gaps.sm,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('change-photo'),
                          onPressed: locked || _pickingPhoto ? null : _choosePhoto,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: Text(l10n.issuesFormPhotoChange),
                        ),
                        TextButton(
                          key: const Key('remove-photo'),
                          onPressed: locked ? null : () => setState(() => _photo = null),
                          child: Text(l10n.issuesFormPhotoRemove),
                        ),
                      ],
                    ),
                  ] else
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        key: const Key('add-photo'),
                        onPressed: locked || _pickingPhoto ? null : _choosePhoto,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(l10n.issuesFormPhotoAdd),
                      ),
                    ),
                  const SizedBox(height: Gaps.lg),
                  LoadingButton(
                    key: const Key('issue-submit'),
                    label: l10n.issuesFormSubmit,
                    // Not while a photo is being chosen or shrunk: it isn't part of the report yet.
                    onPressed: _submitting || _pickingPhoto ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
          if (_submitting)
            Positioned.fill(
              child: _AnalysingOverlay(
                photo: photo,
                cropType: widget.crops
                    .where((crop) => crop.id == _cropId)
                    .map((crop) => crop.cropType)
                    .firstOrNull,
              ),
            ),
        ],
      ),
    );
  }
}

/// Covers the form while the API analyses the report. That can take a minute or more (it runs
/// the photo model and a weather lookup, after any cold start), so it shows the work: the
/// farmer's photo (or the crop's) with a scan line sweeping over it, and the steps ticking off.
/// The server answers in one request and doesn't report progress, so the steps are paced to its
/// usual time and the last stays running until the answer arrives. It can't be tapped through,
/// so the farmer can't send the same report twice. The website's `ReportProgress`.
class _AnalysingOverlay extends ConsumerStatefulWidget {
  const _AnalysingOverlay({required this.photo, required this.cropType});

  final PickedPhoto? photo;
  final String? cropType;

  @override
  ConsumerState<_AnalysingOverlay> createState() => _AnalysingOverlayState();
}

class _AnalysingOverlayState extends ConsumerState<_AnalysingOverlay>
    with SingleTickerProviderStateMixin {
  /// When each step starts, in seconds after sending (photo step included).
  static const _starts = [0.0, 1.5, 6.0, 14.0];

  final Stopwatch _clock = Stopwatch()..start();
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final moving = motionLevel(context, ref) != MotionLevel.off;
    if (moving && !_scan.isAnimating) {
      unawaited(_scan.repeat());
    } else if (!moving) {
      _scan.stop();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final photo = widget.photo;
    final cropType = widget.cropType;
    final steps = [
      l10n.issuesNewProgressSend,
      if (photo != null) l10n.issuesNewProgressPhoto,
      l10n.issuesNewProgressCompare,
      l10n.issuesNewProgressAdvice,
    ];
    final starts = photo != null ? _starts : [_starts[0], _starts[2], _starts[3]];
    final elapsed = _clock.elapsedMilliseconds / 1000;
    final running = starts.where((start) => elapsed >= start).length - 1;
    final current = running.clamp(0, steps.length - 1);

    return ColoredBox(
      key: const Key('analysing'),
      color: colors.surface.withValues(alpha: 0.97),
      child: Semantics(
        liveRegion: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Gaps.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.issuesNewAnalysing, style: textTheme.headlineSmall),
              const SizedBox(height: Gaps.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 220,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (photo != null)
                        Image.memory(photo.bytes, fit: BoxFit.cover)
                      else if (cropType != null)
                        Image.asset(cropPhotoAsset(cropType), fit: BoxFit.cover)
                      else
                        ColoredBox(color: colors.forest),
                      AnimatedBuilder(
                        animation: _scan,
                        builder: (context, _) => _scan.isAnimating
                            ? CustomPaint(painter: _ScanPainter(_scan.value))
                            : const SizedBox.shrink(),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CustomPaint(painter: _CornersPainter()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gaps.md),
              StageList(steps: steps, current: current),
              const SizedBox(height: Gaps.sm),
              Text(
                l10n.issuesNewAnalysingHint,
                style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A soft bright band sweeping down the photo and back, like a scanner.
class _ScanPainter extends CustomPainter {
  _ScanPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
    final band = Rect.fromLTWH(0, y - 36, size.width, 72);
    canvas.drawRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00B5CDA0), Color(0x55B5CDA0), Color(0x00B5CDA0)],
        ).createShader(band),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = const Color(0xCCE8F5D8)
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.t != t;
}

/// Viewfinder corners over the photo.
class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 18.0;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, arm)
      ..lineTo(0, 0)
      ..lineTo(arm, 0)
      ..moveTo(w - arm, 0)
      ..lineTo(w, 0)
      ..lineTo(w, arm)
      ..moveTo(w, h - arm)
      ..lineTo(w, h)
      ..lineTo(w - arm, h)
      ..moveTo(arm, h)
      ..lineTo(0, h)
      ..lineTo(0, h - arm);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CornersPainter old) => false;
}
