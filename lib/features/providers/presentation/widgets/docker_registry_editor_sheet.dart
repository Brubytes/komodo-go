import 'package:flutter/material.dart';
import 'package:komodo_go/core/widgets/sheets/editor_sheet_scaffold.dart';
import 'package:komodo_go/features/providers/data/models/docker_registry_account.dart';
import 'package:komodo_go/features/providers/presentation/widgets/account_editor_fields.dart';

class DockerRegistryEditorResult {
  const DockerRegistryEditorResult({
    required this.domain,
    required this.username,
    required this.token,
  });

  final String domain;
  final String username;
  final String token;
}

class DockerRegistryEditorSheet extends StatefulWidget {
  const DockerRegistryEditorSheet({super.key, this.initial});

  final DockerRegistryAccount? initial;

  static Future<DockerRegistryEditorResult?> show(
    BuildContext context, {
    DockerRegistryAccount? initial,
  }) {
    return showEditorSheet<DockerRegistryEditorResult>(
      context,
      (context) => DockerRegistryEditorSheet(initial: initial),
    );
  }

  @override
  State<DockerRegistryEditorSheet> createState() =>
      _DockerRegistryEditorSheetState();
}

class _DockerRegistryEditorSheetState extends State<DockerRegistryEditorSheet> {
  late final TextEditingController _domainController;
  late final TextEditingController _usernameController;
  late final TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _domainController = TextEditingController(text: initial?.domain ?? '');
    _usernameController = TextEditingController(text: initial?.username ?? '');
    _tokenController = TextEditingController();
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
        _tokenController.text.isNotEmpty;
  }

  bool get _valid =>
      _domainController.text.trim().isNotEmpty &&
      _usernameController.text.trim().isNotEmpty &&
      (_isEditing || _tokenController.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return EditorSheetScaffold(
      title: _isEditing ? 'Edit registry' : 'New registry',
      saveLabel: _isEditing ? 'Save' : 'Create',
      dirty: _dirty,
      canSave: _valid,
      onSave: () => Navigator.of(context).pop(
        DockerRegistryEditorResult(
          domain: _domainController.text.trim(),
          username: _usernameController.text.trim(),
          token: _tokenController.text.trim(),
        ),
      ),
      child: AccountEditorFields(
        domainController: _domainController,
        usernameController: _usernameController,
        tokenController: _tokenController,
        isEditing: _isEditing,
        onChanged: () => setState(() {}),
      ),
    );
  }
}
