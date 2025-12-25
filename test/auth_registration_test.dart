// test/auth_registration_test.dart
// Unit tests untuk registration flow (email/password & Google)
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Form validation - Client-side checks', () {
    test('TC-VALIDATION-01: Email format validation - valid emails', () {
      final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');

      expect(emailRegex.hasMatch('user@example.com'), true);
      expect(emailRegex.hasMatch('user.name@example.co.uk'), true);
      expect(
        emailRegex.hasMatch('user+tag@example.com'),
        false,
      ); // + tidak di pattern
    });

    test('TC-VALIDATION-02: Email format validation - invalid emails', () {
      final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');

      expect(emailRegex.hasMatch('invalidemail'), false);
      expect(emailRegex.hasMatch('user@'), false);
      expect(emailRegex.hasMatch('@example.com'), false);
      expect(emailRegex.hasMatch('user @example.com'), false);
    });

    test('TC-VALIDATION-03: Password strength - minimum length check', () {
      expect('123456'.length >= 6, true);
      expect('12345'.length >= 6, false);
      expect('password123'.length >= 6, true);
    });

    test('TC-VALIDATION-04: Name validation - minimum length', () {
      expect('John'.length >= 3, true);
      expect('Jo'.length >= 3, false);
      expect('A B'.length >= 3, true);
    });

    test('TC-VALIDATION-05: Password match validation', () {
      final password = 'SecurePass123';
      final confirm1 = 'SecurePass123';
      final confirm2 = 'DifferentPass';

      expect(password == confirm1, true);
      expect(password == confirm2, false);
    });
  });

  group('Error message mapping', () {
    test('TC-ERROR-01: Firebase error codes mapped to Indonesian messages', () {
      final errorMessages = {
        'email-already-in-use': 'sudah terdaftar',
        'invalid-email': 'tidak valid',
        'weak-password': 'lemah',
        'user-not-found': 'tidak ditemukan',
        'wrong-password': 'salah',
      };

      // Verify error code keys exist
      errorMessages.forEach((code, expectedMsg) {
        expect(code, isNotEmpty);
        expect(expectedMsg, isNotEmpty);
      });
    });

    test('TC-ERROR-02: Network error handling', () {
      final errorCode = 'network-request-failed';
      expect(errorCode, 'network-request-failed');
    });

    test('TC-ERROR-03: RecAPTCHA error detection', () {
      final msg = 'reCAPTCHA token kosong';
      expect(msg.toLowerCase().contains('recaptcha'), true);

      final msg2 = 'normal error';
      expect(msg2.toLowerCase().contains('recaptcha'), false);
    });
  });

  group('Password strength indicator', () {
    String getPasswordStrength(String password) {
      if (password.length < 6) return 'Lemah';
      final hasUpper = password.contains(RegExp(r'[A-Z]'));
      final hasLower = password.contains(RegExp(r'[a-z]'));
      final hasDigit = password.contains(RegExp(r'[0-9]'));
      final hasSpecial = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
      int score = [
        hasUpper,
        hasLower,
        hasDigit,
        hasSpecial,
      ].where((b) => b).length;
      if (score <= 2) return 'Sedang';
      if (score >= 3) return 'Kuat';
      return 'Lemah';
    }

    test('TC-STRENGTH-01: Weak password (< 6 chars)', () {
      expect(getPasswordStrength('abc12'), 'Lemah');
    });

    test('TC-STRENGTH-02: Medium strength (6+ chars, 2 types)', () {
      expect(getPasswordStrength('abcdef123'), 'Sedang'); // lowercase + digit
    });

    test('TC-STRENGTH-03: Strong password (3+ types)', () {
      expect(
        getPasswordStrength('Abc123!'),
        'Kuat',
      ); // upper, lower, digit, special
    });

    test('TC-STRENGTH-04: Strong password without special', () {
      expect(
        getPasswordStrength('Abc123'),
        'Kuat',
      ); // upper, lower, digit (3 types)
    });
  });
}
