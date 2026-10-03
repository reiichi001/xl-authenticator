import 'package:flutter/material.dart';

import 'package:xl_otpsend/home.dart';

void main() {
  // flutter_secure_storage needs the binding up before it touches platform
  // channels, and HomePage reads the saved secret from initState.
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// The blue of `assets/logo.png`, read out of the asset rather than matched
  /// by eye so the chrome and the logo can't drift apart.
  static const Color brandBlue = Color(0xFF2A65C3);

  /// The trough the OTP bar drains into: the page colour pulled towards the
  /// brand, so the bar stays recognisably blue while sitting clearly behind the
  /// fill. Dark mode needs more of the brand to lift the trough off a near-black
  /// scaffold; light mode needs less, or it stops reading as a trough at all.
  static Color _barTrack(ColorScheme scheme, Brightness brightness) {
    return brightness == Brightness.dark
        ? Color.alphaBlend(
            brandBlue.withValues(alpha: 0.30),
            scheme.surfaceContainerHighest,
          )
        : Color.alphaBlend(brandBlue.withValues(alpha: 0.18), Colors.white);
  }

  /// The "Resend to XL" pill's background.
  ///
  /// ElevatedButton fills itself with `surfaceContainerLow`, which lands within
  /// a few luminance points of the page in *both* brightnesses - not just dark
  /// mode. In light mode that left the pill reading as a bare blue label whose
  /// only edge was its drop shadow. Tinting the page colour toward the brand
  /// gives it a fill that is plainly there: darker than the white page in light
  /// mode, lighter than the near-black one in dark.
  static Color _pillFill(ColorScheme scheme, Brightness brightness) {
    return brightness == Brightness.dark
        ? Color.alphaBlend(
            brandBlue.withValues(alpha: 0.22),
            scheme.surfaceContainerHighest,
          )
        : Color.alphaBlend(brandBlue.withValues(alpha: 0.20), Colors.white);
  }

  /// Builds a theme from the brand blue, with the app bar painted in it.
  ///
  /// The AppBar's `foregroundColor` has to be set alongside its background: it
  /// defaults to `onSurface`, not to `onPrimary`, so setting a colour here
  /// alone leaves the title drawn from the opposite end of the scheme from the
  /// bar behind it - near-black on a saturated blue, or near-white on a tint.
  ///
  /// The bar is the brand blue in *both* brightnesses rather than the scheme's
  /// `primary`. Material 3 lightens `primary` to a pale tint in dark mode, and
  /// a tint of a saturated blue reads as washed-out periwinkle sitting above
  /// the logo.
  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandBlue,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        // The bar is the brand blue in both modes too - a lightened `primary`
        // tint made it a different colour from the logo above it.
        color: brandBlue,
        linearTrackColor: _barTrack(scheme, brightness),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Set in both brightnesses, not just dark: leaving light mode to the
          // default `surfaceContainerLow` is what kept the pill a hair off the
          // page there.
          backgroundColor: _pillFill(scheme, brightness),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Both themes are seeded rather than assembled from the Material 2
    // constructors. `ColorScheme.fromSwatch()` and `ColorScheme.dark()` leave
    // every Material 3 container role null, and ColorScheme's getters fall back
    // silently - which is what made ElevatedButton's fill identical to the
    // scaffold and the progress bar's track identical to its own fill.
    // `fromSeed` fills every role, and derives the on-colours to match.
    return MaterialApp(
      title: 'XL Authenticator',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: HomePage(title: 'XIVLauncher Authenticator'),
    );
  }
}
