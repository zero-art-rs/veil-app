import 'package:flutter/material.dart';
import 'package:zk_notion_app/managers/app_storage.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = AppStorage.shared;

  TextEditingController _nameCtrl = TextEditingController();
  TextEditingController _actorCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    _storage.getAccount().then((value) {
      setState(() {
        _nameCtrl = TextEditingController(text: value?.name ?? '');
        _actorCtrl = TextEditingController(text: value?.actorId ?? '');
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _actorCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final account = await _storage.getAccount();

    if (account?.name == _nameCtrl.text) {
      return;
    }

    setState(() => _saving = true);

    final newAccount = Account.withId(_nameCtrl.text);
    setState(() {
      _actorCtrl.text = newAccount.actorId;
      _storage.setAccount(newAccount);
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Profile',
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
                ],
              ),

              const SizedBox(height: 24),

              // Expanded(
              OutlinedButton.icon(
                onPressed: _onSave,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
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
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.6),
            ),
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
