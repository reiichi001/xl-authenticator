import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAccount {
  static const String secretKey = "SECRET";
  static const String accountNameKey = "ACCOUNT_NAME";

  /// The prefix XIVLauncher puts in front of the Square Enix ID in the OTP
  /// setup URI, which we strip off before showing the name.
  static const String _squareEnixIdPrefix = "Square Enix ID:";

  final String? accountName;
  final String? secret;

  const SavedAccount(this.accountName, this.secret);
  const SavedAccount.unnamed(this.secret) : accountName = '';

  static SavedAccount parse(String uri) {
    final parsedUri = Uri.parse(uri);

    final secret = parsedUri.queryParameters["secret"];

    // The account name is the first path segment with the Square Enix ID
    // prefix stripped. Both are optional in a malformed/partial URI, so fall
    // back to an unnamed account rather than throwing.
    final accountName = parsedUri.pathSegments.isNotEmpty
        ? parsedUri.pathSegments[0].replaceFirst(_squareEnixIdPrefix, '').trim()
        : null;

    return SavedAccount(accountName, secret);
  }

  static Future<SavedAccount?> getSaved() async {
    const secure = FlutterSecureStorage();

    final secret = await secure.read(key: SavedAccount.secretKey);

    if (secret == null) {
      final saved = await getSavedInsecure();

      if (saved != null) {
        await setSaved(saved);
      }

      return saved;
    }

    final accountName = await secure.read(key: SavedAccount.accountNameKey);

    if (accountName == null) {
      return SavedAccount.unnamed(secret);
    }

    return SavedAccount(accountName, secret);
  }

  static Future<SavedAccount?> getSavedInsecure() async {
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(SavedAccount.secretKey)) {
      return null;
    }

    final secret = prefs.getString(SavedAccount.secretKey);

    if (!prefs.containsKey(SavedAccount.accountNameKey)) {
      return SavedAccount.unnamed(secret);
    }

    final accountName = prefs.getString(SavedAccount.accountNameKey);

    return SavedAccount(accountName, secret);
  }

  static Future<void> setSaved(SavedAccount account) async {
    const secure = FlutterSecureStorage();
    await secure.write(key: SavedAccount.secretKey, value: account.secret);

    // parse() returns a null name for a URI with no path segment, and
    // FlutterSecureStorage.write rejects a null value outright, so normalise at
    // the write boundary rather than letting a scan crash on save.
    await secure.write(
        key: SavedAccount.accountNameKey, value: account.accountName ?? '');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SavedAccount.secretKey);
    await prefs.remove(SavedAccount.accountNameKey);
  }

  @override
  String toString() {
    return '${accountName ?? ''} - ${secret ?? ''}';
  }
}
