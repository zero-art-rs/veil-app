import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zk_notion_app/screens/contacts_page.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/storage/models.dart';

import '../main.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _storage = AccountStorage();

  TextEditingController _nameCtrl = TextEditingController();
  TextEditingController _actorCtrl = TextEditingController();
  TextEditingController _pubkeyCtrl = TextEditingController();
  Future<String>? _futureQR;
  late Account? _currentAccount;

  bool _saving = false;

  @override
  void initState() {
    _init();
    super.initState();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _actorCtrl.dispose();
    _pubkeyCtrl.dispose();
    super.dispose();
  }

  _init() async {
    try {
      _currentAccount = await _storage.getAccount();
      logger.d('Current account: $_currentAccount');

      if (_currentAccount == null) {
        return;
      }

      _futureQR = _qrData(_currentAccount!);

      setState(() {
        _nameCtrl = TextEditingController(text: _currentAccount!.name);
        _actorCtrl = TextEditingController(text: _currentAccount!.actorId);
        _pubkeyCtrl = TextEditingController(
          text: _currentAccount!.keypair.publicKey,
        );
      });
    } catch (err) {
      logger.e('Failed to init account page: $err');
    }
  }

  Future<String> _qrData(Account account) async {
    return jsonEncode(ExternalAccount.fromAccount(account));
  }

  Future<void> _onSave() async {
    if (_nameCtrl.text.isEmpty) {
      return;
    }

    setState(() => _saving = true);

    final newAccount = Account.withName(_nameCtrl.text);
    await _storage.setAccount(newAccount);
    _futureQR = _qrData(newAccount);

    setState(() {
      _pubkeyCtrl.text = newAccount.keypair.publicKey;
      _actorCtrl.text = newAccount.actorId;
      _currentAccount = newAccount;
      _saving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: const Text('Account'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: 'Contacts',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ContactsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _LabeledField(
                label: 'Name',
                hint: 'Enter your name',
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Name is required';
                  if (s.length > 64) return 'Name is too long';
                  return null;
                },
                trailing: IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear),
                  onPressed: () => _nameCtrl.clear(),
                ),
              ),
              const SizedBox(height: 12),
              _LabeledField(
                label: 'Actor ID',
                hint: '-',
                controller: _actorCtrl,
                keyboardType: TextInputType.visiblePassword,
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Actor ID is required';
                  final hex = RegExp(r'^0x[0-9a-fA-F]{8,}$');
                  if (!hex.hasMatch(s)) return 'Must be 0x-prefixed hex';
                  return null;
                },
                monospace: true,
                trailing: Row(
                  spacing: 8,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      child: Icon(Icons.copy, size: 22.0),
                      onTap: () => (),
                    ),
                  ],
                ),
                interactionEnabled: false,
              ),
              const SizedBox(height: 12),
              _LabeledField(
                label: 'Public key',
                hint: '-',
                controller: _pubkeyCtrl,
                interactionEnabled: false,
                trailing: Row(
                  spacing: 8,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      child: Icon(Icons.copy, size: 22.0),
                      onTap: () => (),
                    ),
                  ],
                ),
              ),
              Spacer(),
              FutureBuilder<String>(
                future: _futureQR,
                builder: (context, snapshot) {
                  final child =
                      (snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData)
                      ? QrImageView(
                          key: const ValueKey('qr'),
                          data: snapshot.data!,
                          size: 244,
                        )
                      : const SizedBox(
                          key: ValueKey('loader'),
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );

                  return Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (widget, animation) =>
                          FadeTransition(opacity: animation, child: widget),
                      child: child,
                    ),
                  );
                },
              ),

              Spacer(),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _onSave,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    this.textInputAction,
    this.keyboardType,
    this.validator,
    this.trailing,
    this.monospace = false,
    this.interactionEnabled = true,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? trailing;
  final bool monospace;
  final bool interactionEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  enabled: interactionEnabled,
                  controller: controller,
                  textInputAction: textInputAction,
                  keyboardType: keyboardType,
                  validator: validator,
                  style: monospace
                      ? const TextStyle(fontFamily: 'RobotoMono')
                      : null,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: trailing,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
