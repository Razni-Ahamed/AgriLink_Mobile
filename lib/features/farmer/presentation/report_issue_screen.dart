import 'dart:async';

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
          if (_submitting) const Positioned.fill(child: _AnalysingOverlay()),
        ],
      ),
    );
  }
}

/// Covers the form while the API analyses the report. That can take a minute or more (it runs
/// the photo model and a weather lookup, after any cold start), so it says so, and it can't be
/// tapped through, so the farmer can't send the same report twice.
class _AnalysingOverlay extends StatelessWidget {
  const _AnalysingOverlay();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return ColoredBox(
      key: const Key('analysing'),
      color: context.colors.surface.withValues(alpha: 0.96),
      child: Semantics(
        liveRegion: true,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Gaps.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: Gaps.lg),
                Text(
                  l10n.issuesNewAnalysing,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: Gaps.sm),
                Text(
                  l10n.issuesNewAnalysingHint,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
