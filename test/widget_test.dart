// Smoke tests for the app shell.
//
// These keep the platform channels (shared_preferences, flutter_secure_storage)
// mocked so the tests run headless on CI. Note that HomePage runs a repeating
// AnimationController, so `pumpAndSettle` would spin forever: pump explicit
// frames instead.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xl_otpsend/main.dart';

/// Base32 of the RFC 6238 test secret ("12345678901234567890").
const String testSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('opens settings when no account has been saved',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});

    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Set-Up OTP code'), findsOneWidget);
  });

  testWidgets('shows a generated OTP when an account has been saved',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'SECRET': testSecret,
      'ACCOUNT_NAME': 'Test Character',
    });

    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Your OTP:'), findsOneWidget);

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((Text text) => text.data)
        .whereType<String>();

    expect(
      texts.any((String text) => RegExp(r'^\d{6}$').hasMatch(text)),
      isTrue,
      reason: 'expected a 6-digit OTP to be rendered, got: $texts',
    );
  });
}
