import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class Communication {
  static const String ipKey = "IP";

  static Future<String?> getSavedIps() async {
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(ipKey)) {
      return null;
    }

    return prefs.getString(ipKey);
  }

  static Future<void> setSavedIps(String ips) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(ipKey, ips);
  }

  /// Sends [otp] to every configured XIVLauncher IP, separated by `;`.
  ///
  /// Returns whether at least one of them was reached.
  static Future<bool> sendOtp(String otp) async {
    final ips = await Communication.getSavedIps();

    if (ips == null) {
      return false;
    }

    final ipList = ips
        .split(';')
        .map((ip) => ip.trim())
        .where((ip) => ip.isNotEmpty)
        .toList();

    var reachedAny = false;

    for (final ip in ipList) {
      final uri = Uri.http("$ip:4646", "ffxivlauncher/$otp");
      try {
        await http.get(uri);
        reachedAny = true;
      } on http.ClientException catch (e) {
        // This happens since the XL http server is badly implemented, no
        // problem though. Keep going so the remaining IPs are still tried.
        developer.log(
          'ClientException: $uri',
          name: 'com.goatsoft.xl_otpsend',
          error: e,
        );
        reachedAny = true;
      } catch (e) {
        developer.log(
          'could not send to: $uri',
          name: 'com.goatsoft.xl_otpsend',
          error: e,
        );
      }
    }

    return reachedAny;
  }
}
