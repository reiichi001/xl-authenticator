import 'package:shared_preferences/shared_preferences.dart';

class GeneralSetting {
  static const String isCloseKey = "ISCLOSE";

  static Future<bool> getIsAutoClose() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(isCloseKey) ?? false;
  }

  static Future<void> setIsAutoClose(bool state) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(isCloseKey, state);
  }
}
