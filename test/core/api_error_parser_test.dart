import 'package:agrilink_mobile/core/api/api_error_parser.dart';
import 'package:agrilink_mobile/core/api/api_exception.dart';
import 'package:agrilink_mobile/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  ParsedApiError parse(Object error) => parseApiError(error, l10n);

  test('a request that never reached the server gets the network message', () {
    final parsed = parse(const ApiException(ApiErrorKind.network));
    expect(parsed.generalErrors, [l10n.commonErrorsNetwork]);
    expect(parse(const ApiException(ApiErrorKind.timeout)).generalErrors, [
      l10n.commonErrorsNetwork,
    ]);
  });

  test('a 409 is the email clash unless the body says the username', () {
    expect(
      parse(
        ApiException.fromStatus(409, {
          'message': 'An account with this email already exists.',
        }),
      ).generalErrors,
      ['An account with this email already exists.'],
    );
    expect(
      parse(
        ApiException.fromStatus(409, {
          'errors': [
            {
              'code': 'DuplicateUserName',
              'description': 'That username is taken.',
            },
          ],
        }),
      ).generalErrors,
      [l10n.commonValidationUsernameTaken],
    );
  });

  test(
    'Identity error codes are translated, unknown ones use the description',
    () {
      final parsed = parse(
        ApiException.fromStatus(400, {
          'errors': [
            {
              'code': 'PasswordRequiresDigit',
              'description': 'Passwords must have a digit.',
            },
            {'code': 'DuplicateEmail', 'description': 'Email taken.'},
            {'code': 'SomethingNew', 'description': 'A new rule failed.'},
          ],
        }),
      );
      expect(parsed.generalErrors, [
        l10n.commonValidationPasswordDigit,
        l10n.authRegisterEmailExists,
        'A new rule failed.',
      ]);
      expect(parsed.fieldErrors, isEmpty);
    },
  );

  test('validation problem details go under the matching form fields', () {
    final parsed = parse(
      ApiException.fromStatus(400, {
        'title': 'One or more validation errors occurred.',
        'errors': {
          'Email': ['The Email field is not a valid e-mail address.'],
          'NIC': [
            'The field NIC must be a string with a maximum length of 20.',
          ],
          'Unknown': ['Something else.'],
        },
      }),
    );
    expect(parsed.fieldErrors, {
      'email': 'The Email field is not a valid e-mail address.',
      'nic': 'The field NIC must be a string with a maximum length of 20.',
    });
    expect(parsed.generalErrors, ['Something else.']);
  });

  test('a business rule message is shown as it is', () {
    expect(
      parse(
        ApiException.fromStatus(400, {
          'message': 'Enter your field or plot number.',
        }),
      ).generalErrors,
      ['Enter your field or plot number.'],
    );
  });

  test('anything else falls back to the generic message', () {
    expect(parse(ApiException.fromStatus(500)).generalErrors, [
      l10n.authRegisterError,
    ]);
    expect(parse(StateError('bug')).generalErrors, [l10n.authRegisterError]);
    expect(
      parseApiError(
        ApiException.fromStatus(500),
        l10n,
        generic: (l) => l.authProfileEditError,
      ).generalErrors,
      [l10n.authProfileEditError],
    );
  });

  test('describeError gives one line for screens with a retry button', () {
    expect(
      describeError(const ApiException(ApiErrorKind.network), l10n),
      l10n.commonErrorsNetwork,
    );
    expect(
      describeError(ApiException.fromStatus(404), l10n),
      l10n.commonErrorsNotFound,
    );
    expect(
      describeError(
        ApiException.fromStatus(404, {'message': 'Farm not found.'}),
        l10n,
      ),
      'Farm not found.',
    );
    expect(describeError(Exception('x'), l10n), l10n.commonErrorsGeneric);
  });
}
