import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';

import 'package:komodo_go/features/builders/presentation/views/builders/builder_config_editor_sheet.dart';

class BuilderTile extends ConsumerWidget {
  const BuilderTile({required this.item, super.key});

  final BuilderListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = item.info;
    final builderType = info.builderType.trim();
    final instanceType = info.instanceType?.trim();
    final showInstanceType =
        instanceType != null &&
        instanceType.isNotEmpty &&
        !_looksLikeSensitiveId(instanceType);

    return ResourceCard(
      key: ValueKey('builder_card_${item.id}'),
      menuKey: ValueKey('builder_card_menu_${item.id}'),
      title: item.name,
      meta: [
        if (builderType.isNotEmpty)
          ResourceIconLabel(icon: AppIcons.toolbox, label: builderType),
        if (showInstanceType)
          ResourceIconLabel(icon: AppIcons.cpu, label: instanceType),
      ],
      pills: [
        if (item.template) const TextPill(label: 'Template'),
        ...resourceTagPills(item.tags),
      ],
      menu: [
        DetailActionGroup(
          items: [
            DetailActionItem(
              label: 'Edit',
              icon: AppIcons.edit,
              onSelected: () => unawaited(_editConfig(context, ref)),
            ),
            DetailActionItem(
              label: 'Delete',
              icon: AppIcons.delete,
              destructive: true,
              onSelected: () => unawaited(_delete(context, ref)),
            ),
          ],
        ),
      ],
      onTap: () => unawaited(_editConfig(context, ref)),
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
      capabilities: ref.read(komodoApiCapabilitiesProvider),
    );

    if (!context.mounted) return;
    if (result == null) return;

    final nextName = result.name.trim();
    final renameOk =
        !(nextName.isNotEmpty && nextName != item.name) ||
        await ref
            .read(builderActionsProvider.notifier)
            .rename(id: item.id, name: nextName);

    if (!context.mounted) return;

    final ok = await ref
        .read(builderActionsProvider.notifier)
        .updateConfig(id: item.id, config: result.config);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok && renameOk ? 'Builder updated' : 'Failed to update builder',
      tone: ok && renameOk ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete ${item.name}?',
      message: 'This permanently deletes the builder "${item.name}".',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    if (!context.mounted) return;

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
      '^[0-9a-fA-F]{8}-'
      '[0-9a-fA-F]{4}-'
      '[0-9a-fA-F]{4}-'
      '[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{12}$',
    );
    if (uuid.hasMatch(v)) return true;

    // Long hex string (typical for internal IDs)
    final hex = RegExp(r'^[0-9a-fA-F]+$');
    if (hex.hasMatch(v) && v.length >= 16) return true;

    return false;
  }
}
