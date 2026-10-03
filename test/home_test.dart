// Tests for the home screen's OTP read-out: the progress bar and the
// "Resend to XL" button.
//
// HomePage runs a repeating AnimationController, so `pumpAndSettle` would spin
// forever: pump explicit frames instead. Same constraint as widget_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xl_otpsend/main.dart';

/// Base32 of the RFC 6238 test secret ("12345678901234567890").
const String testSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

/// Pumps the home screen with a saved account, in the given brightness.
Future<void> pumpHome(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  FlutterSecureStorage.setMockInitialValues(<String, String>{
    'SECRET': testSecret,
    'ACCOUNT_NAME': 'Test Character',
  });

  await tester.pumpWidget(const MyApp());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Pumps the home screen with a saved account, in dark mode.
Future<void> pumpHomeInDarkMode(WidgetTester tester) => pumpHome(tester);

double progressValue(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value!;

/// The colour the "Resend to XL" pill actually paints itself.
Color? resendFill(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.widgetWithText(ElevatedButton, 'Resend to XL'),
            matching: find.byType(Material),
          )
          .first,
    )
    .color;

/// WCAG contrast between two opaque colours, 1.0 (identical) to 21.0.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();

  return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'OTP bar is the brand blue over a visible trough, in both modes',
    (WidgetTester tester) async {
      for (final brightness in Brightness.values) {
        await pumpHome(tester, brightness: brightness);

        final theme = Theme.of(
          tester.element(find.byType(LinearProgressIndicator)),
        );
        final fill = theme.progressIndicatorTheme.color;
        final track = theme.progressIndicatorTheme.linearTrackColor;

        // The colours come from the theme rather than from colorScheme.primary
        // and secondaryContainer. When the scheme left that track role unset it
        // fell back to `secondary` - which this app set to the same blue as
        // `primary` - so the bar was one uniform colour and could never be seen
        // to move, however far it actually advanced.
        expect(fill, MyApp.brandBlue, reason: '$brightness');
        expect(track, isNotNull, reason: '$brightness');
        expect(track, isNot(fill), reason: '$brightness');

        // And the trough is visible against the page it sits on, which is the
        // part "a different colour" does not cover: the stock dark-mode trough
        // clears the scaffold by a hair and the bar looks like it has no track.
        final page = theme.scaffoldBackgroundColor;
        expect(track, isNot(page), reason: '$brightness');
        expect(
          (track!.computeLuminance() - page.computeLuminance()).abs(),
          greaterThan(0.02),
          reason: '$brightness',
        );
      }
    },
  );

  testWidgets('resend pill separates from the page in both modes', (
    WidgetTester tester,
  ) async {
    for (final brightness in Brightness.values) {
      await pumpHome(tester, brightness: brightness);

      final theme = Theme.of(
        tester.element(find.widgetWithText(ElevatedButton, 'Resend to XL')),
      );
      final page = theme.scaffoldBackgroundColor;
      final fill = resendFill(tester);

      // ElevatedButton fills itself with colorScheme.surfaceContainerLow, which
      // was never the scaffold colour outright - it just sat close enough to it
      // to matter, in light mode as well as dark.
      //
      // Luminance is the wrong yardstick for "can you see it": the dark pill
      // clears the page by only 0.04 there and still reads clearly, because
      // blue is a dark hue and the tint is doing the work. What both fills
      // share, and what an unset theme loses, is the pull toward the brand -
      // so measure that. Channel values are 0..1 here, so the threshold is
      // stated in 8-bit terms: the stock light fill tints the page by 1, the
      // tinted ones by ~28.
      expect(fill, isNotNull, reason: '$brightness');
      expect(fill, isNot(page), reason: '$brightness');
      expect(
        (fill!.b - fill.r) - (page.b - page.r),
        greaterThan(12 / 255),
        reason: '$brightness',
      );

      // The fill has to serve its label, not just the page behind it. The
      // label keeps ElevatedButton's default of colorScheme.primary, which is
      // what the theme leaves unset here.
      final ink =
          theme.elevatedButtonTheme.style?.foregroundColor?.resolve(
            <WidgetState>{},
          ) ??
          theme.colorScheme.primary;

      expect(
        contrastRatio(ink, fill),
        greaterThan(4.5),
        reason: '$brightness label on pill',
      );
    }
  });

  testWidgets('app bar is the brand blue with a readable title in both modes', (
    WidgetTester tester,
  ) async {
    for (final brightness in Brightness.values) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pump();

      final theme = Theme.of(tester.element(find.byType(AppBar)));

      // Both have to be set. Material 3 leaves AppBar's foreground at
      // `onSurface` regardless of its background, so a bar painted from the
      // brand blue without also naming a foreground draws its title from the
      // opposite end of the scheme - black on blue, or white on a pale tint.
      expect(
        theme.appBarTheme.backgroundColor,
        MyApp.brandBlue,
        reason: '$brightness',
      );
      expect(
        theme.appBarTheme.foregroundColor,
        isNotNull,
        reason: '$brightness',
      );

      // And the title really is legible against it, not just "set".
      expect(
        theme.appBarTheme.foregroundColor!.computeLuminance() -
            MyApp.brandBlue.computeLuminance(),
        greaterThan(0.35),
        reason: '$brightness',
      );
    }
  });

  testWidgets('OTP bar counts down in step with the wall clock', (
    WidgetTester tester,
  ) async {
    await pumpHomeInDarkMode(tester);

    final before = progressValue(tester);
    final startedAt = DateTime.now();

    // The bar is drawn from the same clock that generates the code, not from
    // the controller's animation, so it only moves when real time passes:
    // `tester.pump(Duration(...))` advances the test's animation clock and
    // leaves `DateTime.now()` where it was, so a real sleep is the only way to
    // watch this bar move.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );
    await tester.pump();

    final after = progressValue(tester);
    final elapsed = DateTime.now().difference(startedAt);

    // Taken modulo the wrap so a window rolling over mid-test cannot make this
    // flaky. 1.2s of a 30s window is 0.04 of the bar and the tolerance is a
    // tenth of that, so a bar driven by a controller whose 30 seconds began
    // whenever the app did - up to 30s out of phase with the OTP - fails here.
    expect(
      (before - after + 1.0) % 1.0,
      moreOrLessEquals(elapsed.inMilliseconds / 30000, epsilon: 0.004),
    );
  });
}
