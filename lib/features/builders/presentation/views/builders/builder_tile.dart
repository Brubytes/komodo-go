import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pill_list.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';

import 'package:komodo_go/features/builders/presentation/views/builders/builder_config_editor_sheet.dart';

class BuilderTile extends ConsumerWidget {
  const BuilderTile({required this.item, super.key});

  final BuilderListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final info = item.info;
    final builderType = info.builderType.trim();
    final instanceType = info.instanceType?.trim();
    final showInstanceType =
        instanceType != null &&
        instanceType.isNotEmpty &&
        !_looksLikeSensitiveId(instanceType);
    final showBuilderType = builderType.isNotEmpty;
    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: cardRadius,
          onTap: () => _editConfig(context, ref),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: SizedBox(
              width: double.infinity,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 68, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                AppIcons.factory,
                                color: scheme.primary,
                                size: 16,
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: Text(
                                item.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        if (showBuilderType || showInstanceType) ...[
                          const Gap(8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              if (showBuilderType)
                                _IconLabel(
                                  icon: AppIcons.toolbox,
                                  label: builderType,
                                ),
                              if (showInstanceType)
                                _IconLabel(
                                  icon: AppIcons.cpu,
                                  label: instanceType,
                                ),
                            ],
                          ),
                        ],
                        if (item.template || item.tags.isNotEmpty) ...[
                          const Gap(10),
                          DetailPillList(
                            items: item.tags,
                            maxItems: 4,
                            showEmptyLabel: false,
                            leading: [
                              if (item.template)
                                const TextPill(label: 'Template'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: PopupMenuButton<_BuilderAction>(
                        onSelected: (action) async {
                          switch (action) {
                            case _BuilderAction.edit:
                              await _editConfig(context, ref);
                            case _BuilderAction.delete:
                              await _delete(context, ref);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: _BuilderAction.edit,
                            child: Row(
                              children: [
                                Icon(
                                  AppIcons.edit,
                                  color: scheme.primary,
                                  size: 18,
                                ),
                                const Gap(10),
                                const Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _BuilderAction.delete,
                            child: Row(
                              children: [
                                Icon(
                                  AppIcons.delete,
                                  color: scheme.error,
                                  size: 18,
                                ),
                                const Gap(10),
                                const Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

    final nextName = result.name.trim();
    final renameOk = !(nextName.isNotEmpty && nextName != item.name) || await ref
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

enum _BuilderAction { edit, delete }

class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const Gap(6),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
