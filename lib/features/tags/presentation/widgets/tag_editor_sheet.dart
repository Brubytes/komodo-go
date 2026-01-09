import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:komodo_go/core/ui/app_icons.dart';
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
    return showModalBottomSheet<TagEditorResult>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => TagEditorSheet(initial: initial),
    );
  }

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  late final TextEditingController _nameController;
  late TagColor _color;

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
                isEditing ? 'Edit tag' : 'New tag',
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
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(AppIcons.tag),
            ),
          ),
          const Gap(12),
          DropdownButtonFormField<TagColor>(
            value: _color,
            decoration: const InputDecoration(
              labelText: 'Color',
              prefixIcon: Icon(Icons.palette_outlined),
            ),
            items: [
              for (final c in TagColor.values)
                DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: c.swatch,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Gap(10),
                      Text(c.label),
                    ],
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _color = value ?? _color),
          ),
          const Gap(16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.of(context).pop(TagEditorResult(name: name, color: _color));
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
