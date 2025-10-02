import 'dart:convert';

import 'package:veil/storage/app_storage.dart';
import 'package:veil/storage/models.dart';

class AccountSecureStorage {
  final _storage = AppStorage.shared;
  static final AccountSecureStorage instance = AccountSecureStorage();
  static const String _accountKey = 'account';

  late Account account;

  Future<void> init() async {
    account = await _setAccountIfNeeded();
  }

  Future<Account?> _getAccount() async {
    final rawAccount = await _storage.read(key: _accountKey);

    if (rawAccount == null) {
      return null;
    }

    return Account.fromJson(jsonDecode(rawAccount));
  }

  Future<void> setAccount(Account account) async {
    await _storage.write(key: _accountKey, value: jsonEncode(account.toJson()));

    final optionalAccount = await _getAccount();

    if (optionalAccount == null) {
      throw Exception('No account, unreachable flow');
    }

    this.account = optionalAccount;
  }

  Future<Account> _setAccountIfNeeded() async {
    final account = await _getAccount();
    if (account != null) {
      return account;
    }

    final newAccount = Account.withName('Account');
    await setAccount(newAccount);

    return newAccount;
  }
}
