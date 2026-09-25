import 'package:agrilink_mobile/core/validation/validators.dart';
import 'package:agrilink_mobile/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NIC', () {
    test('accepts the new 12-digit and the old 9-digit + V/X formats', () {
      expect(isValidNic('200012345678'), isTrue);
      expect(isValidNic('851234567V'), isTrue);
      expect(isValidNic('851234567x'), isTrue);
      expect(isValidNic(' 851234567v '), isTrue);
    });

    test('rejects anything else', () {
      expect(isValidNic('85123456V'), isFalse);
      expect(isValidNic('2000123456789'), isFalse);
      expect(isValidNic('851234567A'), isFalse);
      expect(isValidNic(''), isFalse);
    });

    test('normalises to an uppercase V or X', () {
      expect(normalizeNic(' 851234567v '), '851234567V');
      expect(normalizeNic('851234567x'), '851234567X');
      expect(normalizeNic('200012345678'), '200012345678');
    });
  });

  group('phone', () {
    test('needs exactly 10 digits after removing spaces and dashes', () {
      expect(normalizePhone('077 123 4567'), '0771234567');
      expect(normalizePhone('077-123-4567'), '0771234567');
      expect(isValidPhone('077 123 4567'), isTrue);
      expect(isValidPhone('+94771234567'), isFalse);
      expect(isValidPhone('077123456'), isFalse);
    });
  });

  group('username', () {
    test('is trimmed and lowercased', () {
      expect(normalizeUsername('  Kamal.Perera '), 'kamal.perera');
    });

    test('reports each problem like UsernamePolicy', () {
      expect(usernameProblem('ab'), UsernameProblem.tooShort);
      expect(usernameProblem('a' * 31), UsernameProblem.tooLong);
      expect(usernameProblem('.kamal'), UsernameProblem.invalid);
      expect(usernameProblem('kamal_'), UsernameProblem.invalid);
      expect(usernameProblem('kamal..perera'), UsernameProblem.invalid);
      expect(usernameProblem('kamal-perera'), UsernameProblem.invalid);
      expect(usernameProblem('admin'), UsernameProblem.reserved);
      expect(usernameProblem('kamal.perera_99'), isNull);
      expect(usernameProblem('abc'), isNull);
    });
  });

  group('password rules', () {
    test('each rule tests one requirement', () {
      expect(PasswordRule.length.test('a' * 11), isFalse);
      expect(PasswordRule.length.test('a' * 12), isTrue);
      expect(PasswordRule.lowercase.test('ABC'), isFalse);
      expect(PasswordRule.uppercase.test('abc'), isFalse);
      expect(PasswordRule.digit.test('abc'), isFalse);
      expect(PasswordRule.symbol.test('abc123'), isFalse);
      expect(PasswordRule.symbol.test('abc 123'), isTrue);
    });

    test('the first failing rule is reported in checklist order', () {
      expect(firstFailedPasswordRule('short'), PasswordRule.length);
      expect(firstFailedPasswordRule('ALLUPPERCASE1!'), PasswordRule.lowercase);
      expect(firstFailedPasswordRule('Gardening2026!'), isNull);
    });
  });

  test('email follows the website pattern', () {
    expect(isValidEmail('kamal@example.lk'), isTrue);
    expect(isValidEmail(' kamal.perera+farm@mail.example.com '), isTrue);
    expect(isValidEmail('kamal@'), isFalse);
    expect(isValidEmail('kamal..perera@example.com'), isFalse);
    expect(isValidEmail('kamal@example'), isFalse);
  });

  group('FormValidators', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final v = FormValidators(l10n);

    test('use the website messages', () {
      expect(v.fullName()('K'), 'Full name is required');
      expect(v.fullName()('Kamal Perera'), isNull);
      expect(v.email()('nope'), 'Enter a valid email');
      expect(v.nic()(''), 'NIC is required');
      expect(v.nic()('12345'), l10n.commonValidationNicInvalid);
      expect(v.nic()('851234567v'), isNull);
      expect(v.username()('Admin'), l10n.commonValidationUsernameReserved);
      expect(v.newPassword()('short'), 'Password must be at least 12 characters');
      expect(v.newPassword()('Gardening2026!'), isNull);
    });

    test('confirmPassword compares with the other field', () {
      final confirm = v.confirmPassword(() => 'Gardening2026!');
      expect(confirm(''), 'Confirm your password');
      expect(confirm('Gardening2026?'), 'Passwords do not match');
      expect(confirm('Gardening2026!'), isNull);
    });

    test('phone uses the messages for its field', () {
      final phone = v.phone(
        requiredMessage: l10n.commonValidationBusinessPhoneRequired,
        invalidMessage: l10n.commonValidationBusinessPhoneInvalid,
      );
      expect(phone(''), l10n.commonValidationBusinessPhoneRequired);
      expect(phone('0771'), 'Business phone must be 10 digits');
      expect(phone('077 123 4567'), isNull);
    });
  });
}
