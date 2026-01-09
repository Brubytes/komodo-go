import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/features/variables/data/models/variable.dart';

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
    return showModalBottomSheet<VariableEditorResult>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => VariableEditorSheet(initial: initial),
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                isEditing ? 'Edit variable' : 'New variable',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(null),
              ),
            ],
          ),
          const Gap(12),
          TextField(
            controller: _nameController,
            enabled: !isEditing,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(AppIcons.tag),
            ),
          ),
          const Gap(12),
          TextField(
            controller: _descriptionController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(AppIcons.edit),
            ),
          ),
          const Gap(12),
          TextField(
            controller: _valueController,
            obscureText: _obscureValue,
            minLines: 1,
            maxLines: _obscureValue ? 1 : 6,
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
          const Gap(10),
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
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) {
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
              },
              child: Text(isEditing ? 'Save' : 'Create'),
            ),
          ),
          const Gap(12),
        ],
      ),
    );
  }
}
