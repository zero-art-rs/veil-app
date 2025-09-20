import 'dart:convert';

import 'package:zk_notion_app/storage/app_storage.dart';
import 'package:zk_notion_app/storage/models.dart';

class AccountStorage {
  final _storage = AppStorage.shared;
  static final AccountStorage instance = AccountStorage();
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
