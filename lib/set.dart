import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:prompt_dialog/prompt_dialog.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:xl_otpsend/account.dart';
import 'package:xl_otpsend/communication.dart';
import 'package:xl_otpsend/generalsetting.dart';
import 'package:xl_otpsend/qr.dart';
import 'package:xl_otpsend/scanresult.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String repoLink =
      "https://github.com/reiichi001/xl-authenticator";

  late bool isRestartChecked = false;

  late bool isAccountSaved = false;
  String? savedName;
  String? savedSecret;

  @override
  void initState() {
    GeneralSetting.getIsAutoClose().then((value) {
      setState(() {
        isRestartChecked = value;
      });
    });

    SavedAccount.getSaved().then((value) {
      setState(() {
        if (value != null) {
          isAccountSaved = true;
          savedName = value.accountName;
          savedSecret = value.secret;
        }
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Read from the scheme so the body text keeps its contrast in either
    // brightness; the hardcoded greys were low-contrast on a dark surface.
    // There is no "success" role, so the good state keeps a fixed green.
    TextStyle defaultStyle = TextStyle(
      color: scheme.onSurfaceVariant,
      fontSize: 13.0,
    );
    TextStyle linkStyle = TextStyle(color: scheme.primary, fontSize: 13.0);

    TextStyle goodStyle = TextStyle(color: Colors.green, fontSize: 13.0);
    TextStyle badStyle = TextStyle(color: scheme.error, fontSize: 13.0);

    return Scaffold(
      // Colours come from the app's AppBarTheme.
      appBar: AppBar(title: Text("Settings")),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(padding: EdgeInsets.only(top: 100.0)),
            RichText(
              text: TextSpan(
                style: defaultStyle,
                children: <TextSpan>[
                  TextSpan(text: 'Registered: '),
                  TextSpan(
                    text: ((() {
                      if (isAccountSaved) {
                        if (savedName != '') {
                          return savedName;
                        }

                        return "Yes";
                      }

                      return "none";
                    })()),
                    style: ((() {
                      if (isAccountSaved) return goodStyle;

                      return badStyle;
                    })()),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        final secret = savedSecret;
                        if (secret != null) {
                          Clipboard.setData(ClipboardData(text: secret));

                          Fluttertoast.showToast(
                            msg: "Secret copied!",
                            toastLength: Toast.LENGTH_LONG,
                            gravity: ToastGravity.BOTTOM,
                            timeInSecForIosWeb: 1,
                            backgroundColor: scheme.error,
                            textColor: scheme.onError,
                            fontSize: 16.0,
                          );
                        }
                      },
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _navigateAndScanQr(context);
              },
              child: Text('Set-Up OTP code'),
            ),
            Padding(
              padding: EdgeInsets.only(top: 40.0),
              child: FutureBuilder(
                future: Communication.getSavedIps(),
                builder: (context, snapshot) {
                  return RichText(
                    text: TextSpan(
                      style: defaultStyle,
                      children: <TextSpan>[
                        TextSpan(text: 'XIVLauncher IP: '),
                        TextSpan(
                          text: ((() {
                            if (snapshot.hasData) {
                              return snapshot.data as String;
                            }

                            return "not set";
                          })()),
                          style: ((() {
                            if (snapshot.hasData) return goodStyle;

                            return badStyle;
                          })()),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              final secret = savedSecret;
                              if (secret != null) {
                                Clipboard.setData(ClipboardData(text: secret));
                              }
                            },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Read the saved IPs first so that no async gap separates the
                // `context` use below from this closure's start.
                final initialValue = await Communication.getSavedIps();

                if (!context.mounted) return;

                final result = await prompt(
                  context,
                  title: Text("Enter XIVLauncher IP"),
                  textOK: Text("OK"),
                  textCancel: Text("Cancel"),
                  maxLines: 1,
                  minLines: 1,
                  autoFocus: true,
                  textCapitalization: TextCapitalization.none,
                  initialValue: initialValue,
                );

                if (result != null) {
                  debugPrint("Manual entry: $result");
                  setState(() {
                    Communication.setSavedIps(result);
                  });
                }
              },
              child: Text('Set XIVLauncher IPs'),
            ),
            RichText(
              text: TextSpan(
                style: defaultStyle,
                text: 'Note: You can set multiple IPs, seperated by ;',
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Row(
                children: [
                  SizedBox(width: 100),
                  Text("Close app after sending:"),
                  Checkbox(
                    value: isRestartChecked,
                    activeColor: scheme.primary,
                    onChanged: (value) {
                      setState(() {
                        isRestartChecked = value as bool;
                        GeneralSetting.setIsAutoClose(value);
                      });
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: 50,
                left: 10,
                right: 10,
                bottom: 100,
              ),
              child: RichText(
                text: TextSpan(
                  style: defaultStyle,
                  children: <TextSpan>[
                    TextSpan(text: 'By goat, see '),
                    TextSpan(
                      text: 'licenses',
                      style: linkStyle,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          showLicensePage(
                            context: context,
                            applicationName: "XL Authenticator",
                            applicationLegalese:
                                "Automatic OTPs for XIVLauncher\n(c) goaaats 2020",
                            applicationIcon: Padding(
                              padding: EdgeInsets.only(left: 100, right: 100),
                              child: Image(
                                image: AssetImage('assets/logo.png'),
                              ),
                            ),
                          );
                        },
                    ),
                    TextSpan(text: ' and '),
                    TextSpan(
                      text: 'source code',
                      style: linkStyle,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          await _openRepoLink();
                        },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRepoLink() async {
    await launchUrl(Uri.parse(repoLink), mode: LaunchMode.externalApplication);
  }

  Future<void> _navigateAndScanQr(BuildContext context) async {
    // Navigator.push returns a Future that completes after calling
    // Navigator.pop on the Selection Screen.
    final result = await Navigator.push<ScanResult>(
      context,
      MaterialPageRoute<ScanResult>(
        builder: (context) => const QRViewExample(),
      ),
    );

    if (result == null || !context.mounted) return;

    final saved = switch (result.type) {
      ScanResultType.uri => SavedAccount.parse(result.data),
      ScanResultType.raw => SavedAccount.unnamed(
        result.data.toString().toUpperCase().replaceAll(" ", ""),
      ),
    };

    setState(() {
      isAccountSaved = true;
      savedName = saved.accountName;
      savedSecret = saved.secret;
    });

    await SavedAccount.setSaved(saved);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text("Saved!")));
  }
}
