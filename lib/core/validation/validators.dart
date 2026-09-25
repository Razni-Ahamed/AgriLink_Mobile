import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';

// The same rules as the website (frontend/src/lib/validation.ts, passwordSchema.ts,
// usernameSchema.ts) and the server (AuthController, UsernamePolicy, Identity options). The
// server checks everything again; these only catch mistakes before a round trip.

/// New NIC format: 12 digits, no letter.
final RegExp nicNewFormat = RegExp(r'^\d{12}$');

/// Old NIC format: 9 digits and a V or X (either case; stored uppercase).
final RegExp nicOldFormat = RegExp(r'^\d{9}[VvXx]$');

/// Sri Lankan local phone numbers: exactly 10 digits, no country code.
final RegExp phonePattern = RegExp(r'^\d{10}$');

/// The pattern zod's `.email()` uses on the website.
final RegExp emailPattern = RegExp(
  r"^(?!\.)(?!.*\.\.)([A-Za-z0-9_'+\-.]*)[A-Za-z0-9_+-]@([A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}$",
);

bool isValidNic(String nic) {
  final trimmed = nic.trim();
  return nicNewFormat.hasMatch(trimmed) || nicOldFormat.hasMatch(trimmed);
}

/// Trims and uppercases a trailing v/x. Doesn't validate.
String normalizeNic(String nic) {
  final trimmed = nic.trim();
  return nicOldFormat.hasMatch(trimmed)
      ? trimmed.substring(0, 9) + trimmed.substring(9).toUpperCase()
      : trimmed;
}

/// Removes spaces and dashes: "077 123 4567" and "077-123-4567" become "0771234567".
String normalizePhone(String phone) => phone.replaceAll(RegExp(r'[\s-]'), '');

bool isValidPhone(String phone) => phonePattern.hasMatch(normalizePhone(phone));

bool isValidEmail(String email) => emailPattern.hasMatch(email.trim());

// Usernames (backend Services/Accounts/UsernamePolicy.cs).

const int usernameMinLength = 3;
const int usernameMaxLength = 30;

/// Lowercase letters, digits, `.` and `_`, starting and ending with a letter or digit.
final RegExp usernamePattern = RegExp(r'^[a-z0-9](?:[a-z0-9._]*[a-z0-9])?$');

const Set<String> reservedUsernames = {
  'admin',
  'administrator',
  'agrilink',
  'support',
  'system',
  'root',
  'officer',
  'farmer',
  'buyer',
  'null',
  'undefined',
  'me',
  'api',
  'help',
};

enum UsernameProblem { tooShort, tooLong, invalid, reserved }

/// Trims and lowercases, as the server does before checking. Send the normalised value.
String normalizeUsername(String username) => username.trim().toLowerCase();

/// What is wrong with an already-normalised username, or null if it passes every rule.
UsernameProblem? usernameProblem(String normalized) {
  if (normalized.length < usernameMinLength) {
    return UsernameProblem.tooShort;
  }
  if (normalized.length > usernameMaxLength) {
    return UsernameProblem.tooLong;
  }
  if (!usernamePattern.hasMatch(normalized) || normalized.contains('..')) {
    return UsernameProblem.invalid;
  }
  if (reservedUsernames.contains(normalized)) {
    return UsernameProblem.reserved;
  }
  return null;
}

// Passwords (Identity options in the backend's Program.cs).

const int passwordMinLength = 12;

/// The password policy. The live checklist shows one row per rule, and validation uses the same
/// rules, so the two can never disagree.
enum PasswordRule {
  length,
  lowercase,
  uppercase,
  digit,
  symbol;

  bool test(String password) => switch (this) {
    PasswordRule.length => password.length >= passwordMinLength,
    PasswordRule.lowercase => RegExp('[a-z]').hasMatch(password),
    PasswordRule.uppercase => RegExp('[A-Z]').hasMatch(password),
    PasswordRule.digit => RegExp('[0-9]').hasMatch(password),
    PasswordRule.symbol => RegExp('[^A-Za-z0-9]').hasMatch(password),
  };

  /// The checklist row ("At least 12 characters").
  String label(AppLocalizations l10n) => switch (this) {
    PasswordRule.length => l10n.commonPasswordChecklistLength,
    PasswordRule.lowercase => l10n.commonPasswordChecklistLowercase,
    PasswordRule.uppercase => l10n.commonPasswordChecklistUppercase,
    PasswordRule.digit => l10n.commonPasswordChecklistDigit,
    PasswordRule.symbol => l10n.commonPasswordChecklistSymbol,
  };

  /// The error when it fails ("Password must be at least 12 characters").
  String message(AppLocalizations l10n) => switch (this) {
    PasswordRule.length => l10n.commonValidationPasswordMin12,
    PasswordRule.lowercase => l10n.commonValidationPasswordLowercase,
    PasswordRule.uppercase => l10n.commonValidationPasswordUppercase,
    PasswordRule.digit => l10n.commonValidationPasswordDigit,
    PasswordRule.symbol => l10n.commonValidationPasswordSymbol,
  };
}

/// The first rule [password] fails, in checklist order, or null if it passes them all.
PasswordRule? firstFailedPasswordRule(String password) {
  for (final rule in PasswordRule.values) {
    if (!rule.test(password)) {
      return rule;
    }
  }
  return null;
}

/// Server-side column lengths (ProfileFieldLimits and the registration DTO).
abstract final class FieldLimits {
  static const int fullName = 100;
  static const int email = 256;
  static const int displayName = 60;
  static const int fieldPlotNumber = 50;
  static const int businessName = 100;
  static const int businessRegistrationNumber = 50;
  static const int legalBusinessName = 100;
}

/// `TextFormField` validators with the website's messages:
///
/// ```dart
/// final v = FormValidators(context.l10n);
/// TextFormField(validator: v.nic(), ...)
/// TextFormField(validator: v.all([v.required(l10n.x), v.maxLength(50, l10n.y)]))
/// ```
class FormValidators {
  const FormValidators(this.l10n);

  final AppLocalizations l10n;

  /// Runs each validator in turn and returns the first error.
  FormFieldValidator<String> all(List<FormFieldValidator<String>> validators) =>
      (value) {
        for (final validator in validators) {
          final error = validator(value);
          if (error != null) {
            return error;
          }
        }
        return null;
      };

  /// Fails when the trimmed value is shorter than [min] (1 means "not empty").
  FormFieldValidator<String> required(String message, {int min = 1}) =>
      (value) => (value ?? '').trim().length < min ? message : null;

  FormFieldValidator<String> maxLength(int max, String message) =>
      (value) => (value ?? '').trim().length > max ? message : null;

  FormFieldValidator<String> fullName() => all([
    required(l10n.commonValidationFullNameRequired, min: 2),
    maxLength(FieldLimits.fullName, l10n.commonValidationNameTooLong),
  ]);

  FormFieldValidator<String> email() => all([
    required(l10n.commonValidationEmailInvalid),
    (value) =>
        isValidEmail(value ?? '') ? null : l10n.commonValidationEmailInvalid,
    maxLength(FieldLimits.email, l10n.commonValidationEmailTooLong),
  ]);

  /// For sign-in, where any stored password is accepted: only "not empty".
  FormFieldValidator<String> passwordEntered() =>
      required(l10n.commonValidationPasswordRequired);

  /// For a new password: the full policy.
  FormFieldValidator<String> newPassword() =>
      (value) => firstFailedPasswordRule(value ?? '')?.message(l10n);

  FormFieldValidator<String> confirmPassword(String Function() password) =>
      (value) {
        if ((value ?? '').isEmpty) {
          return l10n.commonValidationConfirmPasswordRequired;
        }
        return value == password()
            ? null
            : l10n.commonValidationConfirmPasswordMismatch;
      };

  FormFieldValidator<String> username() => (value) {
    final problem = usernameProblem(normalizeUsername(value ?? ''));
    return switch (problem) {
      null => null,
      UsernameProblem.tooShort => l10n.commonValidationUsernameTooShort,
      UsernameProblem.tooLong => l10n.commonValidationUsernameTooLong,
      UsernameProblem.invalid => l10n.commonValidationUsernameInvalid,
      UsernameProblem.reserved => l10n.commonValidationUsernameReserved,
    };
  };

  FormFieldValidator<String> nic() => (value) {
    if ((value ?? '').trim().isEmpty) {
      return l10n.commonValidationNicRequired;
    }
    return isValidNic(normalizeNic(value!))
        ? null
        : l10n.commonValidationNicInvalid;
  };

  /// A 10-digit phone number, with the field's own messages (phone or business phone).
  FormFieldValidator<String> phone({
    required String requiredMessage,
    required String invalidMessage,
  }) => (value) {
    if ((value ?? '').trim().isEmpty) {
      return requiredMessage;
    }
    return isValidPhone(value!) ? null : invalidMessage;
  };
}
