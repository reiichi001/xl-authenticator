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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Stopwatch refreshStopwatch;

  String? savedSecret;

  int timeOffset = 0;

  String _currentOtp = "";

  @override
  void initState() {
    setup();

    var startTimestep = getTimestep();

    timeOffset = (30000 * startTimestep).floor();
    debugPrint("timeOffset:$timeOffset");

    refreshStopwatch = Stopwatch();
    refreshStopwatch.start();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(() {
        setState(() {
          //debugPrint("refresh: " + controller.value.toString());
          if (refreshStopwatch.elapsedMilliseconds > 30000 - timeOffset) {
            timeOffset = 0;
            _currentOtp = getCode();
            refreshStopwatch.reset();

            debugPrint("refresh!! $timeOffset");
          }
        });
      });
    controller.forward(from: startTimestep);
    controller.repeat(reverse: false);

    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Marks that the one-time storage notice has been shown, so it never
  /// reappears after the first time.
  static const String _storageNoticeShownKey = "STORAGE_NOTICE_SHOWN";

  /// Explains the 1.0.6 secure-storage change on Android, once per install.
  ///
  /// The old plugin stored the secret with AES-CBC/RSA-PKCS1; the new one
  /// migrates that to AES-GCM/OAEP on first launch. That normally happens
  /// invisibly, but if it ever fails the user is left with an empty settings
  /// screen and no idea why, so everyone gets told once rather than only the
  /// users we can already see are missing a secret.
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
            'If your secret is missing, scan the QR code from XIVLauncher '
            'again to set it up. Nothing else about the app has changed.'),
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
      Fluttertoast.showToast(
          msg: "OTP sent!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);

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
        secret, DateTime.now().millisecondsSinceEpoch,
        length: 6, interval: 30, algorithm: Algorithm.SHA1, isGoogle: true);
  }

  void showNewOtp() {
    setState(() {
      OTP.useTOTPPaddingForHOTP = true;
      _currentOtp = getCode();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'XL Authenticator'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Container(
                padding:
                    const EdgeInsets.only(top: 100.0, left: 100.0, right: 100.0),
                child: Image.asset("assets/logo.png", width: 200.0)),
            const Padding(
              padding: EdgeInsets.only(top: 60.0),
              child: Text(
                'Your OTP:',
              ),
            ),
            Text(
              _currentOtp,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Padding(
                padding: const EdgeInsets.all(20.0),
                child: LinearProgressIndicator(
                  value: controller.value,
                  semanticsLabel: 'Linear progress indicator',
                )),
            Padding(
              padding: const EdgeInsets.only(top: 15.0, bottom: 100.0),
              child: ElevatedButton(
                onPressed: () async {
                  final res = await Communication.sendOtp(getCode());

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context)
                    ..removeCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text(
                          res ? "Sent!" : "IP not set or connection failed"),
                      backgroundColor: Colors.blueAccent,
                    ));
                },
                child: const Text('Resend to XL'),
              ),
            )
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
