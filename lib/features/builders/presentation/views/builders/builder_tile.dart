import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pill_list.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/detail/detail_surface.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';

import 'builder_config_editor_sheet.dart';

class BuilderTile extends ConsumerWidget {
  const BuilderTile({required this.item, super.key});

  final BuilderListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final info = item.info;
    final instanceType = info.instanceType?.trim();
    final showInstanceType =
        instanceType != null &&
        instanceType.isNotEmpty &&
        !_looksLikeSensitiveId(instanceType);

    return DetailSurface(
      padding: const EdgeInsets.all(14),
      radius: 20,
      enableGradientInDark: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(AppIcons.factory, color: scheme.primary, size: 18),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      info.instanceType?.trim().isNotEmpty ?? false
                          ? (showInstanceType
                                ? '${info.builderType} • $instanceType'
                                : info.builderType)
                          : info.builderType,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_BuilderAction>(
                onSelected: (action) async {
                  switch (action) {
                    case _BuilderAction.editConfig:
                      await _editConfig(context, ref);
                    case _BuilderAction.rename:
                      await _rename(context, ref);
                    case _BuilderAction.delete:
                      await _delete(context, ref);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _BuilderAction.editConfig,
                    child: Row(
                      children: [
                        Icon(AppIcons.edit, color: scheme.primary, size: 18),
                        const Gap(10),
                        const Text('Edit config'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _BuilderAction.rename,
                    child: Row(
                      children: [
                        Icon(AppIcons.edit, color: scheme.primary, size: 18),
                        const Gap(10),
                        const Text('Rename'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _BuilderAction.delete,
                    child: Row(
                      children: [
                        Icon(AppIcons.delete, color: scheme.error, size: 18),
                        const Gap(10),
                        const Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.template) const TextPill(label: 'Template'),
              if (info.builderType.trim().isNotEmpty)
                TextPill(label: info.builderType),
              if (showInstanceType)
                ValuePill(label: 'Instance', value: instanceType),
            ],
          ),
          if (item.tags.isNotEmpty) ...[
            const Gap(10),
            DetailPillList(
              items: item.tags,
              maxItems: 6,
              moreLabel: 'More',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editConfig(BuildContext context, WidgetRef ref) async {
    final json = await ref.read(builderJsonProvider(item.id).future);
    if (!context.mounted) return;

    if (json == null) {
      AppSnackBar.show(
        context,
        'Failed to load builder config',
        tone: AppSnackBarTone.error,
      );
      return;
    }

    final result = await BuilderConfigEditorSheet.show(
      context,
      builderName: item.name,
      builderType: item.info.builderType,
      builderJson: json,
    );

    if (!context.mounted) return;
    if (result == null) return;

    final ok = await ref
        .read(builderActionsProvider.notifier)
        .updateConfig(id: item.id, config: result.config);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Builder updated' : 'Failed to update builder',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: item.name);
    final nextName = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename builder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (nextName == null || nextName.isEmpty) return;
    final ok = await ref
        .read(builderActionsProvider.notifier)
        .rename(id: item.id, name: nextName);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Builder renamed' : 'Failed to rename builder',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete builder'),
        content: Text('Delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref
        .read(builderActionsProvider.notifier)
        .delete(id: item.id);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Builder deleted' : 'Failed to delete builder',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  bool _looksLikeSensitiveId(String value) {
    final v = value.trim();
    if (v.length < 12) return false;

    // UUID
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{12}$',
    );
    if (uuid.hasMatch(v)) return true;

    // Long hex string (typical for internal IDs)
    final hex = RegExp(r'^[0-9a-fA-F]+$');
    if (hex.hasMatch(v) && v.length >= 16) return true;

    return false;
  }
}

enum _BuilderAction { editConfig, rename, delete }
