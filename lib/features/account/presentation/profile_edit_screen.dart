import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/shell/agrilink_app_bar.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_error_parser.dart';
import '../../../core/format/formatters.dart';
import '../../../core/session/role.dart';
import '../../../core/validation/validators.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/media/photo_picker.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/application/current_user.dart';
import '../../auth/application/username_availability.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/presentation/widgets/username_availability_hint.dart';
import '../data/account_api.dart';
import '../data/account_models.dart';

/// Editing the profile, with the website's rules: each field starts empty with the current
/// value as its hint, an empty field keeps the current value, and only changed fields are
/// sent. A new photo is uploaded only when the user saves.
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AgriLinkAppBar(title: l10n.authProfileEditEditProfile),
      body: user == null
          ? LoadingView(message: l10n.authProfileLoading)
          : _ProfileEditForm(user: user),
    );
  }
}

sealed class _PhotoChange {
  const _PhotoChange();
}

class _KeepPhoto extends _PhotoChange {
  const _KeepPhoto();
}

class _RemovePhoto extends _PhotoChange {
  const _RemovePhoto();
}

class _NewPhoto extends _PhotoChange {
  const _NewPhoto(this.photo);
  final PickedPhoto photo;
}

class _ProfileEditForm extends ConsumerStatefulWidget {
  const _ProfileEditForm({required this.user});

  final UserProfile user;

  @override
  ConsumerState<_ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends ConsumerState<_ProfileEditForm> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  final _fieldPlotNumber = TextEditingController();
  final _businessName = TextEditingController();

  late final UsernameAvailabilityChecker _usernameCheck;

  _PhotoChange _photo = const _KeepPhoto();
  bool _useFullName = false;
  bool _saving = false;
  String? _usernameError;

  UserProfile get _user => widget.user;

  @override
  void initState() {
    super.initState();
    _usernameCheck = UsernameAvailabilityChecker(
      ref.read(authApiProvider),
      currentUsername: widget.user.username,
    );
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _fieldPlotNumber.dispose();
    _businessName.dispose();
    _usernameCheck.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final photo = await pickPhoto(context, ref);
    if (photo != null && mounted) {
      setState(() => _photo = _NewPhoto(photo));
    }
  }

  void _removePhoto() {
    setState(
      () => _photo = _user.profilePhotoUrl != null ? const _RemovePhoto() : const _KeepPhoto(),
    );
  }

  UpdateProfileRequest _changes() {
    final displayName = _displayName.text.trim();
    final username = normalizeUsername(_username.text);
    final plot = _fieldPlotNumber.text.trim();
    final business = _businessName.text.trim();
    return UpdateProfileRequest(
      displayName: _useFullName
          ? ''
          : displayName.isNotEmpty && displayName != (_user.displayName ?? '')
          ? displayName
          : null,
      username: _user.canChangeUsername() && username.isNotEmpty && username != _user.username
          ? username
          : null,
      fieldPlotNumber: _user.role == Role.farmer && plot.isNotEmpty && plot != _user.fieldPlotNumber
          ? plot
          : null,
      businessName:
          _user.role == Role.buyer && business.isNotEmpty && business != _user.businessName
          ? business
          : null,
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _usernameError = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final changes = _changes();
    if (changes.username != null && _usernameCheck.value == UsernameStatus.taken) {
      setState(() => _usernameError = l10n.commonValidationUsernameTaken);
      return;
    }
    if (changes.isEmpty && _photo is _KeepPhoto) {
      showToast(context, l10n.authProfileEditNoChanges);
      context.go(AppRoutes.profile);
      return;
    }

    final api = ref.read(accountApiProvider);
    final currentUser = ref.read(currentUserProvider.notifier);
    setState(() => _saving = true);
    try {
      UserProfile? latest;
      switch (_photo) {
        case _NewPhoto(:final photo):
          latest = await api.uploadPhoto(photo);
        case _RemovePhoto():
          latest = await api.deletePhoto();
        case _KeepPhoto():
          break;
      }
      if (!changes.isEmpty) {
        latest = await api.updateProfile(changes);
      }
      if (latest != null) {
        currentUser.set(latest);
      }
      if (mounted) {
        showToast(context, l10n.authProfileEditSuccess, tone: ToastTone.success);
        context.go(AppRoutes.profile);
      }
    } on Object catch (error) {
      // Even a partial failure (the photo saved, then the details refused) changed something,
      // so read the profile again to keep it truthful.
      await currentUser.refresh();
      if (mounted) {
        final parsed = parseApiError(error, l10n, generic: (l) => l.authProfileEditError);
        showToast(context, parsed.summary, tone: ToastTone.error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final v = FormValidators(l10n);
    final format = ref.watch(formattersProvider);
    final textTheme = Theme.of(context).textTheme;
    final hintStyle = textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);
    final usernameLocked = !_user.canChangeUsername();
    final showsPhoto = switch (_photo) {
      _NewPhoto() => true,
      _RemovePhoto() => false,
      _KeepPhoto() => _user.profilePhotoUrl != null,
    };

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(Gaps.md),
        children: [
          Text(l10n.authProfileEditPhotoLabel, style: textTheme.titleSmall),
          const SizedBox(height: Gaps.sm),
          Row(
            children: [
              switch (_photo) {
                _NewPhoto(:final photo) => ClipOval(
                  child: Image.memory(
                    photo.bytes,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    semanticLabel: _user.shownName,
                  ),
                ),
                _RemovePhoto() => UserAvatar(role: _user.role, name: _user.shownName, size: 72),
                _KeepPhoto() => UserAvatar(
                  role: _user.role,
                  name: _user.shownName,
                  photoUrl: _user.profilePhotoUrl,
                  size: 72,
                ),
              },
              const SizedBox(width: Gaps.md),
              Expanded(
                child: Wrap(
                  spacing: Gaps.sm,
                  runSpacing: Gaps.sm,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('change-photo'),
                      onPressed: _saving ? null : _choosePhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(l10n.authProfileEditChangePhoto),
                    ),
                    if (showsPhoto)
                      TextButton(
                        key: const Key('remove-photo'),
                        onPressed: _saving ? null : _removePhoto,
                        child: Text(l10n.authProfileEditRemovePhoto),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.sm),
          Semantics(
            liveRegion: true,
            child: Text(switch (_photo) {
              _NewPhoto() => l10n.authProfileEditPhotoPreview,
              _RemovePhoto() => l10n.authProfileEditPhotoWillBeRemoved,
              _KeepPhoto() => l10n.authProfileEditPhotoHint,
            }, style: hintStyle),
          ),
          const SizedBox(height: Gaps.lg),
          AppTextField(
            fieldKey: const Key('edit-displayName'),
            controller: _displayName,
            label: l10n.authProfileGeneralDisplayName,
            hint: _user.displayName ?? _user.fullName,
            enabled: !_useFullName,
            textCapitalization: TextCapitalization.words,
            maxLength: FieldLimits.displayName * 2,
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.length > FieldLimits.displayName) {
                return l10n.authProfileEditDisplayNameTooLong;
              }
              if (text.runes.any((c) => c < 32 || c == 127)) {
                return l10n.authProfileEditDisplayNameInvalid;
              }
              return null;
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _useFullName
                      ? l10n.authProfileEditUsingFullName
                      : l10n.authProfileEditDisplayNameHint,
                  style: hintStyle,
                ),
                if (_user.displayName?.trim().isNotEmpty ?? false)
                  TextButton(
                    onPressed: () => setState(() => _useFullName = !_useFullName),
                    child: Text(
                      _useFullName ? l10n.authProfileEditCancel : l10n.authProfileEditUseFullName,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Gaps.md),
          AppTextField(
            fieldKey: const Key('edit-username'),
            controller: _username,
            label: l10n.commonFieldsUsername,
            hint: _user.username,
            enabled: !usernameLocked,
            autocorrect: false,
            maxLength: 64,
            serverError: _usernameError,
            validator: (value) => (value ?? '').trim().isEmpty ? null : v.username()(value),
            onChanged: (value) {
              setState(() => _usernameError = null);
              _usernameCheck.update(value);
            },
          ),
          if (usernameLocked)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                l10n.authProfileEditUsernameLocked(format.date(_user.usernameChangeAvailableAt!)),
                style: hintStyle,
              ),
            )
          else ...[
            ValueListenableBuilder(
              valueListenable: _usernameCheck,
              builder: (context, status, _) => UsernameAvailabilityHint(status: status),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(l10n.authProfileEditUsernameEvery30Days, style: hintStyle),
            ),
          ],
          if (_user.role == Role.farmer) ...[
            const SizedBox(height: Gaps.md),
            AppTextField(
              fieldKey: const Key('edit-fieldPlotNumber'),
              controller: _fieldPlotNumber,
              label: l10n.commonFieldsFieldPlotNumber,
              hint: _user.fieldPlotNumber,
              validator: v.maxLength(
                FieldLimits.fieldPlotNumber,
                l10n.commonValidationFieldPlotNumberTooLong,
              ),
            ),
          ],
          if (_user.role == Role.buyer) ...[
            const SizedBox(height: Gaps.md),
            AppTextField(
              fieldKey: const Key('edit-businessName'),
              controller: _businessName,
              label: l10n.commonFieldsBusinessName,
              hint: _user.businessName,
              textCapitalization: TextCapitalization.words,
              validator: v.maxLength(
                FieldLimits.businessName,
                l10n.authProfileEditBusinessNameTooLong,
              ),
            ),
          ],
          if (_user.role == Role.farmer || _user.role == Role.buyer)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(l10n.authProfileEditKeepCurrent, style: hintStyle),
            ),
          const SizedBox(height: Gaps.lg),
          LoadingButton(
            key: const Key('save-profile'),
            label: l10n.authProfileEditUpdateProfile,
            loadingLabel: l10n.authProfileEditUpdating,
            loading: _saving,
            onPressed: _save,
          ),
          const SizedBox(height: Gaps.sm),
          TextButton(
            onPressed: _saving ? null : () => context.go(AppRoutes.profile),
            child: Text(l10n.authProfileEditCancel),
          ),
        ],
      ),
    );
  }
}
