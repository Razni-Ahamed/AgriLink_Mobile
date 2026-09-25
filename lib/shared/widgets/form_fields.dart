import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/format/formatters.dart';
import '../../core/validation/validators.dart';
import '../../l10n/l10n.dart';

/// A labelled text field. [serverError] shows an error from the API under the field until
/// the user edits it (clear it in `onChanged`).
///
/// ```dart
/// AppTextField(
///   controller: _email,
///   label: l10n.commonFieldsEmail,
///   keyboardType: TextInputType.emailAddress,
///   autofillHints: const [AutofillHints.email],
///   validator: validators.email(),
///   serverError: _fieldErrors['email'],
/// )
/// ```
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.validator,
    this.serverError,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.readOnly = false,
    this.autocorrect = true,
    this.prefixIcon,
    this.suffix,
    this.onTap,
    this.fieldKey,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final String? serverError;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int? maxLines;
  final bool enabled;
  final bool readOnly;
  final bool autocorrect;
  final Widget? prefixIcon;
  final Widget? suffix;
  final VoidCallback? onTap;

  /// Key for the inner [TextFormField], e.g. to find it in tests.
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      validator: validator,
      forceErrorText: serverError,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: keyboardType,
      textInputAction: maxLines == 1 ? textInputAction : TextInputAction.newline,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      enableSuggestions: autocorrect,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon: prefixIcon,
        suffixIcon: suffix,
        counterText: '',
      ),
    );
  }
}

/// A password field with a show/hide button.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    this.controller,
    required this.label,
    this.validator,
    this.serverError,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction = TextInputAction.next,
    this.isNewPassword = false,
    this.fieldKey,
  });

  final TextEditingController? controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final String? serverError;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction textInputAction;

  /// Offers the password manager's "suggest a strong password" instead of autofilling.
  final bool isNewPassword;
  final Key? fieldKey;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      validator: widget.validator,
      forceErrorText: widget.serverError,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: [
        if (widget.isNewPassword) AutofillHints.newPassword else AutofillHints.password,
      ],
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _obscured ? l10n.commonActionsShowPassword : l10n.commonActionsHidePassword,
          icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}

/// The live password checklist: one row per rule, ticked as the user types. Use it under
/// every new-password field.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final style = Theme.of(context).textTheme.bodySmall;
    return Semantics(
      container: true,
      label: l10n.commonPasswordChecklistAriaLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rule in PasswordRule.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _ChecklistRow(
                label: rule.label(l10n),
                met: rule.test(password),
                checked: password.isNotEmpty,
                style: style,
                metColor: colors.success,
                unmetColor: password.isEmpty ? colors.textSecondary : colors.danger,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.met,
    required this.checked,
    required this.style,
    required this.metColor,
    required this.unmetColor,
  });

  final String label;
  final bool met;
  final bool checked;
  final TextStyle? style;
  final Color metColor;
  final Color unmetColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = met ? metColor : unmetColor;
    final state = !checked
        ? l10n.commonPasswordChecklistNotChecked
        : met
        ? l10n.commonPasswordChecklistMet
        : l10n.commonPasswordChecklistNotMet;
    return Semantics(
      label: '$label, $state',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: style?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// A dropdown with the app's field styling.
///
/// ```dart
/// AppDropdownField<String>(
///   label: l10n.commonFieldsCropType,
///   value: _cropType,
///   items: {for (final c in cropTypes) c: cropLabel(l10n, c)},
///   onChanged: (v) => setState(() => _cropType = v),
///   validator: (v) => v == null ? l10n.commonValidationCropTypeRequired : null,
/// )
/// ```
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.validator,
    this.serverError,
    this.enabled = true,
  });

  final String label;

  /// Each value and the text shown for it, in display order.
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;
  final T? value;
  final String? hint;
  final FormFieldValidator<T>? validator;
  final String? serverError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      validator: validator,
      forceErrorText: serverError,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      borderRadius: BorderRadius.circular(16),
      decoration: InputDecoration(labelText: label, hintText: hint),
      items: [
        for (final entry in items.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// A read-only field that opens the date picker. Dates are shown in the app's language.
class AppDateField extends ConsumerWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.validator,
    this.serverError,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final FormFieldValidator<DateTime>? validator;
  final String? serverError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(formattersProvider);
    return FormField<DateTime>(
      initialValue: value,
      validator: validator,
      forceErrorText: serverError,
      builder: (field) {
        Future<void> pick() async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: field.value ?? now,
            firstDate: firstDate ?? DateTime(now.year - 5),
            lastDate: lastDate ?? DateTime(now.year + 5),
          );
          if (picked != null) {
            field.didChange(picked);
            onChanged(picked);
          }
        }

        return InkWell(
          onTap: pick,
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            isEmpty: field.value == null,
            child: Text(field.value == null ? '' : format.date(field.value!)),
          ),
        );
      },
    );
  }
}

/// A primary button that shows a spinner and ignores taps while [loading].
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Shown while loading, e.g. "Signing in…". Defaults to [label].
  final String? loadingLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onPrimary;
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
              ),
            )
          else if (icon != null)
            Padding(padding: const EdgeInsets.only(right: 8), child: Icon(icon, size: 20)),
          Flexible(
            child: Text(loading ? (loadingLabel ?? label) : label, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

/// The red box for errors that don't belong to one field. Read out when it appears.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.messages, this.title, this.action});

  final List<String> messages;
  final String? title;

  /// E.g. a "Try again" button for a connection problem.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }
    return _Banner(
      color: context.colors.danger,
      icon: Icons.error_outline,
      title: title,
      messages: messages,
      action: action,
    );
  }
}

/// A neutral or success notice in the same shape as [ErrorBanner].
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.title, this.success = false});

  final String message;
  final String? title;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      color: success ? context.colors.success : context.colors.info,
      icon: success ? Icons.check_circle_outline : Icons.info_outline,
      title: title,
      messages: [message],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.messages,
    this.title,
    this.action,
  });

  final Color color;
  final IconData icon;
  final List<String> messages;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.tint(color),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(title!, style: textTheme.titleSmall?.copyWith(color: color)),
                      ),
                    for (final message in messages)
                      Text(
                        message,
                        style: textTheme.bodyMedium?.copyWith(color: context.colors.textPrimary),
                      ),
                    if (action != null) Align(alignment: Alignment.centerLeft, child: action),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
