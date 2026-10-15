import 'package:flutter/material.dart';
import 'package:komodo_go/core/widgets/sheets/editor_sheet_scaffold.dart';
import 'package:komodo_go/features/providers/data/models/git_provider_account.dart';
import 'package:komodo_go/features/providers/presentation/widgets/account_editor_fields.dart';

class GitProviderEditorResult {
  const GitProviderEditorResult({
    required this.domain,
    required this.username,
    required this.token,
    required this.https,
  });

  final String domain;
  final String username;
  final String token;
  final bool https;
}

class GitProviderEditorSheet extends StatefulWidget {
  const GitProviderEditorSheet({super.key, this.initial});

  final GitProviderAccount? initial;

  static Future<GitProviderEditorResult?> show(
    BuildContext context, {
    GitProviderAccount? initial,
  }) {
    return showEditorSheet<GitProviderEditorResult>(
      context,
      (context) => GitProviderEditorSheet(initial: initial),
    );
  }

  @override
  State<GitProviderEditorSheet> createState() => _GitProviderEditorSheetState();
}

class _GitProviderEditorSheetState extends State<GitProviderEditorSheet> {
  late final TextEditingController _domainController;
  late final TextEditingController _usernameController;
  late final TextEditingController _tokenController;
  var _https = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _domainController = TextEditingController(text: initial?.domain ?? '');
    _usernameController = TextEditingController(text: initial?.username ?? '');
    _tokenController = TextEditingController();
    _https = initial?.https ?? true;
  }

  @override
  void dispose() {
    _domainController.dispose();
    _usernameController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.initial != null;

  bool get _dirty {
    final initial = widget.initial;
    return _domainController.text != (initial?.domain ?? '') ||
        _usernameController.text != (initial?.username ?? '') ||
        _tokenController.text.isNotEmpty ||
        _https != (initial?.https ?? true);
  }

  bool get _valid =>
      _domainController.text.trim().isNotEmpty &&
      _usernameController.text.trim().isNotEmpty &&
      (_isEditing || _tokenController.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return EditorSheetScaffold(
      title: _isEditing ? 'Edit provider' : 'New provider',
      saveLabel: _isEditing ? 'Save' : 'Create',
      dirty: _dirty,
      canSave: _valid,
      onSave: () => Navigator.of(context).pop(
        GitProviderEditorResult(
          domain: _domainController.text.trim(),
          username: _usernameController.text.trim(),
          token: _tokenController.text.trim(),
          https: _https,
        ),
      ),
      child: AccountEditorFields(
        domainController: _domainController,
        usernameController: _usernameController,
        tokenController: _tokenController,
        isEditing: _isEditing,
        onChanged: () => setState(() {}),
        footer: SwitchListTile.adaptive(
          value: _https,
          onChanged: (value) => setState(() => _https = value),
          title: const Text('Use HTTPS'),
          subtitle: const Text(
            'Enable HTTPS for provider authentication requests.',
          ),
        ),
      ),
    );
  }
}
