import 'dart:convert';

import 'package:veil/storage/app_storage.dart';
import 'package:veil/storage/models/account.dart';


class AccountSecureStorage {
  static final AccountSecureStorage instance = AccountSecureStorage._();

  final AppStorage _storage = AppStorage.shared;
  static const String _accountKey = 'account';

  Account? _account;

  AccountSecureStorage._();

  Account get account {
    if (_account == null) {
      throw StateError('Account not initialized. Call init() first.');
    }
    return _account!;
  }

  Future<void> init() async {
    _account = await _loadOrCreateAccount();
  }

  Future<void> clear() async {
    await _storage.clear();
    _account = null;
  }

  Future<Account?> _getStoredAccount() async {
    final rawAccount = await _storage.read(key: _accountKey);
    if (rawAccount == null) return null;

    try {
      final Map<String, dynamic> json = jsonDecode(rawAccount);
      return Account.fromJson(json);
    } catch (e) {
      await _storage.remove(key: _accountKey);
      return null;
    }
  }

  Future<void> setAccount(Account account) async {
    await _storage.write(key: _accountKey, value: jsonEncode(account.toJson()));
    _account = account;
  }

  Future<Account> _loadOrCreateAccount() async {
    final existing = await _getStoredAccount();
    if (existing != null) return existing;

    final newAccount = Account.withName('Account');
    await setAccount(newAccount);
    return newAccount;
  }
}

extension AccountStorageTest on AccountSecureStorage {
  void testInit() {
    _account = Account.withName('Account');
  }
}
