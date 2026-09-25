import '../../l10n/l10n.dart';
import 'api_exception.dart';

/// What a form shows for a failed request: messages under specific fields, and messages for
/// a general error box.
class ParsedApiError {
  const ParsedApiError({
    this.fieldErrors = const {},
    this.generalErrors = const [],
  });

  /// The form's field name → the message to show under it.
  final Map<String, String> fieldErrors;

  /// Messages that don't belong to one field.
  final List<String> generalErrors;

  /// Everything in one string, e.g. for a snackbar.
  String get summary => [...generalErrors, ...fieldErrors.values].join('\n');
}

typedef MessageOf = String Function(AppLocalizations l10n);

/// ASP.NET `ValidationProblemDetails` field names (from the DTO attributes) → the form field
/// names used across the app's forms. Same table as the website's apiErrors.ts.
const Map<String, String> defaultServerFieldNames = {
  'FullName': 'fullName',
  'Email': 'email',
  'Username': 'username',
  'Password': 'password',
  'NIC': 'nic',
  'District': 'district',
  'FieldPlotNumber': 'fieldPlotNumber',
  'PhoneNumber': 'phoneNumber',
  'BusinessRegistrationNumber': 'businessRegistrationNumber',
  'BusinessPhone': 'businessPhone',
  'LegalBusinessName': 'legalBusinessName',
};

/// Identity's error codes are stable (unlike its English descriptions), so they map to the
/// same wording the password checklist and field validation use. Other codes fall back to the
/// server's description.
final Map<String, MessageOf> _identityCodeMessages = {
  'PasswordTooShort': (l) => l.commonValidationPasswordMin12,
  'PasswordRequiresUpper': (l) => l.commonValidationPasswordUppercase,
  'PasswordRequiresLower': (l) => l.commonValidationPasswordLowercase,
  'PasswordRequiresDigit': (l) => l.commonValidationPasswordDigit,
  'PasswordRequiresNonAlphanumeric': (l) => l.commonValidationPasswordSymbol,
  'InvalidEmail': (l) => l.commonValidationEmailInvalid,
};

const _duplicateEmailCode = 'DuplicateEmail';
const _duplicateUserNameCode = 'DuplicateUserName';

/// Turns any error from an API call into messages a form can show. Handles every shape the API
/// returns, like the website's `parseApiError`:
///
/// - no response at all → [network] ("Can't reach the server…")
/// - 409 → "username is taken" for a `DuplicateUserName` code, otherwise [conflict]
/// - `{ errors: [{ code, description }] }` (Identity) → translated by code
/// - `{ errors: { Field: [msg] } }` (validation) → under the matching form field
/// - `{ message }` → that message
/// - anything else → [generic]
///
/// The defaults suit registration; other forms pass their own messages, e.g.
/// `parseApiError(e, l10n, generic: (l) => l.authProfileEditError)`.
ParsedApiError parseApiError(
  Object error,
  AppLocalizations l10n, {
  MessageOf? generic,
  MessageOf? network,
  MessageOf? conflict,
  Map<String, String> serverFieldNames = defaultServerFieldNames,
}) {
  final genericMessage = (generic ?? (l) => l.authRegisterError)(l10n);
  final networkMessage = (network ?? (l) => l.commonErrorsNetwork)(l10n);
  final conflictMessage = (conflict ?? (l) => l.authRegisterEmailExists)(l10n);

  if (error is! ApiException) {
    return ParsedApiError(generalErrors: [genericMessage]);
  }
  if (error.isConnectivity) {
    return ParsedApiError(generalErrors: [networkMessage]);
  }

  final body = error.data;
  if (error.kind == ApiErrorKind.conflict) {
    // An email clash and a username clash are both 409s; only the body says which.
    return ParsedApiError(
      generalErrors: [
        _hasErrorCode(body, _duplicateUserNameCode)
            ? l10n.commonValidationUsernameTaken
            : conflictMessage,
      ],
    );
  }

  if (body is Map) {
    final errors = body['errors'];
    if (errors is List) {
      final general = <String>[];
      for (final item in errors) {
        if (item is Map && item.containsKey('description')) {
          final code = item['code'];
          final message = switch (code) {
            _duplicateUserNameCode => l10n.commonValidationUsernameTaken,
            _duplicateEmailCode => conflictMessage,
            final String c when _identityCodeMessages.containsKey(c) =>
              _identityCodeMessages[c]!(l10n),
            _ => (item['description'] as String?) ?? genericMessage,
          };
          general.add(message);
        } else {
          general.add('$item');
        }
      }
      if (general.isNotEmpty) {
        return ParsedApiError(generalErrors: general);
      }
    } else if (errors is Map) {
      final fields = <String, String>{};
      final general = <String>[];
      for (final entry in errors.entries) {
        final messages = entry.value;
        final message = messages is List && messages.isNotEmpty
            ? '${messages.first}'
            : '$messages';
        final formField = serverFieldNames[entry.key];
        if (formField != null) {
          fields[formField] = message;
        } else {
          general.add(message);
        }
      }
      if (fields.isNotEmpty || general.isNotEmpty) {
        return ParsedApiError(fieldErrors: fields, generalErrors: general);
      }
    } else if (error.serverMessage != null) {
      return ParsedApiError(generalErrors: [error.serverMessage!]);
    }
  }

  return ParsedApiError(generalErrors: [genericMessage]);
}

bool _hasErrorCode(Object? body, String code) {
  if (body is! Map) {
    return false;
  }
  final errors = body['errors'];
  return errors is List &&
      errors.any((item) => item is Map && item['code'] == code);
}

/// A one-line message for any error, for screens that show an error with a retry button
/// rather than a form. Connectivity problems get the friendly "Can't reach the server".
String describeError(Object error, AppLocalizations l10n) {
  if (error is ApiException) {
    switch (error.kind) {
      case ApiErrorKind.network:
        return l10n.commonErrorsNetwork;
      case ApiErrorKind.timeout:
        return '${l10n.commonErrorsNetwork}\n${l10n.commonErrorsSlowServer}';
      case ApiErrorKind.unauthorized:
        return l10n.commonErrorsSessionExpired;
      case ApiErrorKind.forbidden:
        return error.serverMessage ?? l10n.commonErrorsForbidden;
      case ApiErrorKind.notFound:
        return error.serverMessage ?? l10n.commonErrorsNotFound;
      case ApiErrorKind.cancelled:
      case ApiErrorKind.badRequest:
      case ApiErrorKind.conflict:
      case ApiErrorKind.server:
      case ApiErrorKind.unknown:
        return error.serverMessage ?? l10n.commonErrorsGeneric;
    }
  }
  return l10n.commonErrorsGeneric;
}
