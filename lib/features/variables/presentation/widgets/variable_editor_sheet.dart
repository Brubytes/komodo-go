import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/sheets/editor_sheet_scaffold.dart';
import 'package:komodo_go/features/variables/data/models/variable.dart';
import 'package:komodo_go/features/variables/domain/variable_validation.dart';

class VariableEditorResult {
  const VariableEditorResult({
    required this.name,
    required this.value,
    required this.description,
    required this.isSecret,
  });

  final String name;
  final String value;
  final String description;
  final bool isSecret;
}

class VariableEditorSheet extends StatefulWidget {
  const VariableEditorSheet({super.key, this.initial});

  final KomodoVariable? initial;

  static Future<VariableEditorResult?> show(
    BuildContext context, {
    KomodoVariable? initial,
  }) {
    return showEditorSheet<VariableEditorResult>(
      context,
      (context) => VariableEditorSheet(initial: initial),
    );
  }

  @override
  State<VariableEditorSheet> createState() => _VariableEditorSheetState();
}

class _VariableEditorSheetState extends State<VariableEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late final TextEditingController _descriptionController;
  var _isSecret = false;
  var _obscureValue = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _valueController = TextEditingController(text: initial?.value ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _isSecret = initial?.isSecret ?? false;
    _obscureValue = _isSecret;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _dirty {
    final initial = widget.initial;
    return _nameController.text != (initial?.name ?? '') ||
        _valueController.text != (initial?.value ?? '') ||
        _descriptionController.text != (initial?.description ?? '') ||
        _isSecret != (initial?.isSecret ?? false);
  }

  void _save() {
    final name = _nameController.text.trim();
    final validationError = validateVariableName(name);
    if (validationError != null) {
      setState(() => _nameError = validationError);
      return;
    }
    Navigator.of(context).pop(
      VariableEditorResult(
        name: name,
        value: _valueController.text,
        description: _descriptionController.text,
        isSecret: _isSecret,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return EditorSheetScaffold(
      title: isEditing ? 'Edit variable' : 'New variable',
      saveLabel: isEditing ? 'Save' : 'Create',
      dirty: _dirty,
      canSave: isEditing || _nameController.text.trim().isNotEmpty,
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            enabled: !isEditing,
            textInputAction: TextInputAction.next,
            maxLength: variableNameMaxLength,
            onChanged: (value) => setState(() {
              _nameError = value.trim().isEmpty
                  ? null
                  : validateVariableName(value);
            }),
            decoration: InputDecoration(
              labelText: 'Name',
              prefixIcon: const Icon(AppIcons.tag),
              errorText: _nameError,
              helperText: 'Letters, numbers, and underscores only',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionController,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(AppIcons.edit),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _valueController,
            obscureText: _obscureValue,
            minLines: 1,
            maxLines: _obscureValue ? 1 : 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Value',
              prefixIcon: const Icon(AppIcons.key),
              suffixIcon: IconButton(
                tooltip: _obscureValue ? 'Show' : 'Hide',
                icon: Icon(_obscureValue ? AppIcons.eye : AppIcons.eyeOff),
                onPressed: () => setState(() => _obscureValue = !_obscureValue),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile.adaptive(
            value: _isSecret,
            onChanged: (value) {
              setState(() {
                _isSecret = value;
                if (_isSecret) _obscureValue = true;
              });
            },
            title: const Text('Secret'),
            subtitle: const Text(
              'Secret variables have their values hidden for non-admin users.',
            ),
          ),
        ],
      ),
    );
  }
}
