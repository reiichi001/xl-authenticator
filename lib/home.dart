import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:otp/otp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:xl_otpsend/account.dart';
import 'package:xl_otpsend/communication.dart';
import 'package:xl_otpsend/generalsetting.dart';
import 'package:xl_otpsend/set.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.title});

  final String? title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  String? savedSecret;

  /// The 30-second window the OTP on screen was generated for, as
  /// `millisecondsSinceEpoch ~/ 30000`. The frame listener compares it against
  /// the clock, so this is also how the code turns over.
  int _otpWindow = -1;

  String _currentOtp = "";

  @override
  void initState() {
    setup();

    // The controller is only a frame pump. It drives the AnimatedBuilder that
    // repaints the progress bar and the listener below that watches for the
    // window rolling over; nothing draws its own value, so its duration and
    // phase carry no meaning. Running the bar off the clock instead of off the
    // controller is what keeps it honest - the controller's 30 seconds start
    // whenever the app did, not when the OTP window did, so the bar used to
    // finish about a second and a half early and the OTP refresh used to pick
    // up a frame of lag per cycle, forever.
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(_onFrame);

    controller.repeat();

    super.initState();
  }

  /// Runs every frame, so it stays cheap: the progress bar repaints itself from
  /// the AnimatedBuilder in `build`, and only a new OTP is worth a `setState`.
  void _onFrame() {
    if (savedSecret == null) return;

    if (getWindow() != _otpWindow) {
      setState(() {
        _otpWindow = getWindow();
        _currentOtp = getCode();
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Marks that the one-time storage notice has been shown, so it never
  /// reappears after the first time.
  static const String _storageNoticeShownKey = "STORAGE_NOTICE_SHOWN";

  /// Explains the secure-storage change on Android, once per install.
  ///
  /// The migration to the stronger cipher runs invisibly when it works; when it
  /// fails the user is left with an empty settings screen and no idea why, so
  /// everyone is told once rather than only the users we can already see are
  /// missing a secret.
  Future<void> _maybeShowStorageNotice() async {
    if (!Platform.isAndroid) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_storageNoticeShownKey) ?? false) {
      return;
    }

    await prefs.setBool(_storageNoticeShownKey, true);

    // setup() runs from initState(), before the first frame has been painted,
    // and a route cannot be pushed until the tree is mounted.
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign-in secret storage updated'),
        content: const Text(
          'This version stores your authenticator secret with stronger '
          'encryption, and an existing secret is upgraded automatically '
          'when the app starts.\n\n'
          'If your OTP config is missing, you will need to remove and re-add '
          'on Mog Station to set it up again. Nothing else about the app has changed.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> setup() async {
    await _maybeShowStorageNotice();

    final savedAccount = await SavedAccount.getSaved();

    if (savedAccount == null) {
      debugPrint("No secret found, opening settings");

      if (!mounted) return;
      await openSettings();
      return;
    }

    final secret = savedAccount.secret;

    if (secret == null) {
      debugPrint("Saved account has no secret, opening settings");

      if (!mounted) return;
      await openSettings();
      return;
    }

    savedSecret = secret;
    showNewOtp();

    final sent = await Communication.sendOtp(_currentOtp);
    final isClose = await GeneralSetting.getIsAutoClose();

    if (sent && isClose) {
      // Guarded because this runs after two awaits and Theme.of() on an
      // unmounted State would throw.
      if (mounted) {
        final scheme = Theme.of(context).colorScheme;

        Fluttertoast.showToast(
          msg: "OTP sent!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: scheme.error,
          textColor: scheme.onError,
          fontSize: 16.0,
        );
      }

      SystemNavigator.pop();

      // This is illegal but we're not on the App Store anyway
      if (Platform.isIOS) {
        exit(0);
      }
    }
  }

  Future<void> openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );

    if (!mounted) return;

    final savedAccount = await SavedAccount.getSaved();

    if (savedAccount != null && mounted) {
      debugPrint("Updating secret...");

      setState(() {
        savedSecret = savedAccount.secret;
      });
    }
  }

  /// Which 30-second window the clock is in. The same indexing the OTP itself
  /// uses, so a code and the bar below it always belong to the same window.
  int getWindow() {
    return DateTime.now().millisecondsSinceEpoch ~/ 30000;
  }

  double getCurrentInterval() {
    var ms = DateTime.now().millisecondsSinceEpoch;

    return ms / 30000;
  }

  double getTimestep() {
    var interval = getCurrentInterval();

    return (interval - interval.truncate());
  }

  String getCode() {
    final secret = savedSecret;

    if (secret == null) {
      return "???";
    }

    return OTP.generateTOTPCodeString(
      secret,
      DateTime.now().millisecondsSinceEpoch,
      length: 6,
      interval: 30,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );
  }

  void showNewOtp() {
    setState(() {
      OTP.useTOTPPaddingForHOTP = true;
      _otpWindow = getWindow();
      _currentOtp = getCode();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Colours come from the app's AppBarTheme, so the title and the bar
      // cannot drift apart here.
      appBar: AppBar(title: Text(widget.title ?? 'XL Authenticator')),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(
                top: 100.0,
                left: 100.0,
                right: 100.0,
              ),
              child: Image.asset("assets/logo.png", width: 200.0),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 60.0),
              child: Text('Your OTP:'),
            ),
            Text(
              _currentOtp,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, child) => LinearProgressIndicator(
                  // Counts down: full when the OTP is fresh, empty exactly as
                  // it expires, read from the same clock that generated the
                  // code rather than from the controller's own cycle.
                  //
                  // Fill and track both come from ProgressIndicatorTheme in
                  // main.dart - the brand blue, and a trough blended from it -
                  // rather than from colorScheme roles, which is what let the
                  // bar render as one flat colour.
                  value: 1.0 - getTimestep(),
                  semanticsLabel: 'OTP validity remaining',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 15.0, bottom: 100.0),
              child: ElevatedButton(
                onPressed: () async {
                  final res = await Communication.sendOtp(getCode());

                  if (!context.mounted) return;

                  final scheme = Theme.of(context).colorScheme;

                  ScaffoldMessenger.of(context)
                    ..removeCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          res ? "Sent!" : "IP not set or connection failed",
                          style: TextStyle(color: scheme.onPrimary),
                        ),
                        backgroundColor: scheme.primary,
                      ),
                    );
                },
                child: const Text('Resend to XL'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openSettings,
        tooltip: 'Settings',
        child: const Icon(Icons.settings),
      ),
    );
  }
}
