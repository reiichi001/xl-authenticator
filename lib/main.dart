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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XL Authenticator',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSwatch().copyWith(primary: Colors.blueAccent, secondary: Colors.blueAccent),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(primary: Colors.blueAccent, secondary: Colors.blueAccent),
      ),
      home: HomePage(title: 'XIVLauncher Authenticator'),
    );
  }
}