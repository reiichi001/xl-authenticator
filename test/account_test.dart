import 'package:flutter_test/flutter_test.dart';
import 'package:otp/otp.dart';

import 'package:xl_otpsend/account.dart';
import 'package:xl_otpsend/scanresult.dart';

/// Base32 of the RFC 6238 test secret ("12345678901234567890").
const String testSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

void main() {
  group('SavedAccount.parse', () {
    test('strips the Square Enix ID prefix from the account name', () {
      final account = SavedAccount.parse(
        'otpauth://totp/Square%20Enix%20ID:Test%20Character?secret=ABC123',
      );

      expect(account.accountName, 'Test Character');
      expect(account.secret, 'ABC123');
    });

    test('does not throw on a URI with no path', () {
      final account = SavedAccount.parse('otpauth://totp?secret=ABC123');

      expect(account.accountName, isNull);
      expect(account.secret, 'ABC123');
    });

    test('returns a null secret when the query parameter is missing', () {
      final account = SavedAccount.parse(
        'otpauth://totp/Square%20Enix%20ID:Test',
      );

      expect(account.accountName, 'Test');
      expect(account.secret, isNull);
    });
  });

  test('SavedAccount.unnamed uses an empty account name', () {
    const account = SavedAccount.unnamed(testSecret);

    expect(account.accountName, '');
    expect(account.secret, testSecret);
  });

  test('toString tolerates null fields', () {
    const account = SavedAccount(null, null);

    expect(account.toString(), ' - ');
  });

  test('generates the RFC 6238 SHA-1 test vector', () {
    // T=59s => 8-digit code 94287082, so the 6-digit code is 287082.
    final code = OTP.generateTOTPCodeString(
      testSecret,
      59000,
      length: 6,
      interval: 30,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );

    expect(code, '287082');
  });

  test('ScanResult carries its type and data', () {
    const uriResult = ScanResult.uri('otpauth://totp/x');
    const rawResult = ScanResult.raw(testSecret);

    expect(uriResult.type, ScanResultType.uri);
    expect(uriResult.data, 'otpauth://totp/x');
    expect(rawResult.type, ScanResultType.raw);
    expect(rawResult.data, testSecret);
  });
}
