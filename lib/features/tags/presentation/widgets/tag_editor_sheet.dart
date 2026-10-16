import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/sheets/editor_sheet_scaffold.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';

class TagEditorResult {
  const TagEditorResult({required this.name, required this.color});

  final String name;
  final TagColor color;
}

class TagEditorSheet extends StatefulWidget {
  const TagEditorSheet({super.key, this.initial});

  final KomodoTag? initial;

  static Future<TagEditorResult?> show(
    BuildContext context, {
    KomodoTag? initial,
  }) {
    return showEditorSheet<TagEditorResult>(
      context,
      (context) => TagEditorSheet(initial: initial),
    );
  }

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  late final TextEditingController _nameController;
  late TagColor _color;
  var _touched = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _color = widget.initial?.color ?? TagColor.slate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickColor(BuildContext context) async {
    final selected = await Navigator.of(context, rootNavigator: true)
        .push<TagColor?>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _TagColorPickerPage(initial: _color),
          ),
        );

    if (!mounted) return;
    if (selected != null) {
      setState(() => _color = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    final name = _nameController.text.trim();
    final dirty =
        name != (widget.initial?.name ?? '') ||
        _color != (widget.initial?.color ?? TagColor.slate);

    return EditorSheetScaffold(
      title: isEditing ? 'Edit tag' : 'New tag',
      saveLabel: isEditing ? 'Save' : 'Create',
      dirty: dirty,
      canSave: name.isNotEmpty,
      onSave: () =>
          Navigator.of(context).pop(TagEditorResult(name: name, color: _color)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('tag_editor_name'),
            controller: _nameController,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _touched = true),
            decoration: InputDecoration(
              labelText: 'Name',
              prefixIcon: const Icon(AppIcons.tag),
              errorText: _touched && name.isEmpty ? 'Enter a tag name.' : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            key: const ValueKey('tag_editor_color'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pickColor(context),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Color',
                prefixIcon: Icon(Icons.palette_outlined),
              ),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _color.swatch,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(_color.label)),
                  const Icon(Icons.expand_more, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagColorPickerPage extends StatelessWidget {
  const _TagColorPickerPage({required this.initial});

  final TagColor initial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Select color'),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: TagColor.values.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          itemBuilder: (context, index) {
            final c = TagColor.values[index];
            final isSelected = c == initial;
            return ListTile(
              leading: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: c.swatch,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              title: Text(c.label),
              trailing: isSelected ? const Icon(Icons.check, size: 20) : null,
              onTap: () => Navigator.of(context).pop(c),
            );
          },
        ),
      ),
    );
  }
}
