import 'dart:convert';

import 'package:veil/storage/app_storage.dart';
import 'package:veil/storage/models.dart';

class AppSecureStorage {
  final _storage = AppStorage.shared;
  static final AppSecureStorage instance = AppSecureStorage();
  static const String _accountKey = 'account';

  Future<Account?> getAccount() async {
    final rawAccount = await _storage.read(key: _accountKey);

    if (rawAccount == null) {
      return null;
    }

    return Account.fromJson(jsonDecode(rawAccount));
  }

  Future<void> setAccount(Account account) async {
    await _storage.write(key: _accountKey, value: jsonEncode(account.toJson()));
  }

  Future<void> setSpk(List<int> secretKey, List<int> publicKey) async {
    final base64SecretKey = base64Encode(secretKey);
    final base64PublicKey = base64Encode(publicKey);

    await _storage.write(key: base64PublicKey, value: base64SecretKey);
  }

  Future<List<int>?> getSpkPrivateKey(String publicKey) async {
    final base64PrivateKey = await _storage.read(key: publicKey);
    if (base64PrivateKey == null) {
      return null;
    }

    return base64Decode(base64PrivateKey);
  }

  Future<void> removeSpk(String publicKey) async {
    await _storage.remove(key: publicKey);
  }

  Future<Account> setAccountIfNeeded() async {
    final account = await getAccount();
    if (account != null) {
      return account;
    }

    final newAccount = Account.withName('Account');
    await setAccount(newAccount);

    return newAccount;
  }
}
