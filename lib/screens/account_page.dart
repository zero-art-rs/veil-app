import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:veil/managers/sharing/deeplink_manager.dart';
import 'package:veil/managers/sharing/spk_manager.dart';
import 'package:veil/screens/contacts_page.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/utils/platform.dart';
import 'package:veil/utils/qr.dart';

import '../main.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _storage = AccountSecureStorage();
  final _account = AccountSecureStorage.instance.account;

  TextEditingController _nameCtrl = TextEditingController();
  TextEditingController _actorCtrl = TextEditingController();
  TextEditingController _pubkeyCtrl = TextEditingController();

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

  void _init() {
    try {
      setState(() {
        _nameCtrl = TextEditingController(text: _account.name);
        _actorCtrl = TextEditingController(text: _account.actorId);
        _pubkeyCtrl = TextEditingController(
          text: _account.keypair.publicKeyHex,
        );
      });
    } catch (err) {
      logger.e('Failed to init account page: $err');
    }
  }

  Future<void> _onSave() async {
    if (_nameCtrl.text.isEmpty) {
      return;
    }

    setState(() => _saving = true);

    final newAccount = Account(
      actorId: _account.actorId,
      name: _nameCtrl.text,
      keypair: _account.keypair,
    );

    await _storage.setAccount(newAccount);

    setState(() {
      _pubkeyCtrl.text = newAccount.keypair.publicKeyHex;
      _actorCtrl.text = newAccount.actorId;
      _saving = false;
    });
  }

  void _showShareModal() async {
    final th = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final payload = await SpkManager.instance.createAccountSpks(_account);
    final deeplink = DeeplinkManager.instance.buildContactDeepLink(payload);
    final qrData = QrUtils.instance.buildShareContactData(payload);

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(blurRadius: 20, color: Colors.black.withAlpha(30)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 32,
            children: [
              QrImageView(
                key: const ValueKey('qr'),
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.white,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.white,
                ),
                data: qrData,
              ),
              Text(
                "Let someone scan your CR code or copy the link",
                style: th.bodyLarge,
              ),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      child: const Text("Close"),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Clipboard.setData(ClipboardData(text: deeplink));

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Link copied to clipboard"),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                      child: const Text("Copy link"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformUtils.isDesktop;

    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: const Text('Account'),
        ),
        actions: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'Contacts',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ContactsScreen()),
              ),
            ),

          IconButton(
            icon: Icon(isDesktop ? Icons.ios_share_rounded : Icons.ios_share),
            tooltip: 'Share account',
            onPressed: () => _showShareModal(),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy, size: 22.0),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _actorCtrl.text));
                        HapticFeedback.lightImpact();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Actor ID copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
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
                trailing: IconButton(
                  icon: Icon(Icons.copy, size: 22.0),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _pubkeyCtrl.text));
                    HapticFeedback.lightImpact();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Public key copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
              Spacer(),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
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
