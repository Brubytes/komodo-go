import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/app_floating_action_button.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:komodo_go/features/tags/presentation/widgets/tag_editor_sheet.dart';
import 'package:komodo_go/features/users/presentation/providers/username_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

class TagsView extends ConsumerWidget {
  const TagsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    final actionsState = ref.watch(tagActionsProvider);

    return Scaffold(
      appBar: const MainAppBar(
        title: 'Tags',
        icon: AppIcons.tag,
        centerTitle: true,
      ),
      floatingActionButton: AppSecondaryFab.extended(
        key: const ValueKey('tags_add'),
        onPressed: actionsState.isLoading
            ? null
            : () async {
                final result = await TagEditorSheet.show(context);
                if (result == null) return;

                final ok = await ref
                    .read(tagActionsProvider.notifier)
                    .create(name: result.name, color: result.color);

                if (!context.mounted) return;
                AppSnackBar.show(
                  context,
                  ok ? 'Tag created' : 'Failed to create tag',
                  tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
                );
              },
        icon: const Icon(AppIcons.add),
        label: const Text('Add'),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(tagsProvider.notifier).refresh(),
            child: tagsAsync.when(
              data: (tags) {
                if (tags.isEmpty) {
                  return const _EmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tags.length,
                  separatorBuilder: (_, __) => const Gap(12),
                  itemBuilder: (context, index) => AppFadeSlide(
                    delay: AppMotion.stagger(index),
                    play: index < 10,
                    child: _TagTile(
                      tag: tags[index],
                      onEdit: () async {
                        final tag = tags[index];
                        final result = await TagEditorSheet.show(
                          context,
                          initial: tag,
                        );
                        if (result == null) return;

                        final ok = await ref
                            .read(tagActionsProvider.notifier)
                            .update(
                              original: tag,
                              name: result.name,
                              color: result.color,
                            );

                        if (!context.mounted) return;
                        AppSnackBar.show(
                          context,
                          ok ? 'Tag updated' : 'Failed to update tag',
                          tone: ok
                              ? AppSnackBarTone.success
                              : AppSnackBarTone.error,
                        );
                      },
                      onDelete: () async {
                        final tag = tags[index];
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            key: ValueKey('tag_delete_dialog_${tag.id}'),
                            title: const Text('Delete tag'),
                            content: Text(
                              'Delete "${tag.name}"? This removes it from all resources.',
                            ),
                            actions: [
                              TextButton(
                                key: ValueKey('tag_delete_cancel_${tag.id}'),
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                key: ValueKey('tag_delete_confirm_${tag.id}'),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;

                        final ok = await ref
                            .read(tagActionsProvider.notifier)
                            .delete(tag.id);

                        if (!context.mounted) return;
                        AppSnackBar.show(
                          context,
                          ok ? 'Tag deleted' : 'Failed to delete tag',
                          tone: ok
                              ? AppSnackBarTone.success
                              : AppSnackBarTone.error,
                        );
                      },
                    ),
                  ),
                );
              },
              loading: () => const _TagsSkeletonList(),
              error: (error, _) => ErrorStateView(
                title: 'Failed to load tags',
                message: error.toString(),
                onRetry: () => ref.invalidate(tagsProvider),
              ),
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.scrim.withValues(alpha: 0.25),
              child: const Center(child: AppSkeletonCard()),
            ),
        ],
      ),
    );
  }
}

class _TagTile extends StatelessWidget {
  const _TagTile({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
  });

  final KomodoTag tag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Consumer(
        builder: (context, ref, _) {
          final ownerNameAsync = ref.watch(usernameProvider(tag.owner));
          final ownerLabel = ownerNameAsync.maybeWhen(
            data: (name) =>
                (name == null || name.trim().isEmpty) ? tag.owner : name,
            orElse: () => tag.owner,
          );

          return Material(
            color: Colors.transparent,
            borderRadius: cardRadius,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: ValueKey('tag_tile_${tag.id}'),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tag.color.swatch.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(AppIcons.tag, color: tag.color.swatch, size: 18),
              ),
              title: Text(
                tag.name,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'Owner: $ownerLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: PopupMenuButton<_TagAction>(
                key: ValueKey('tag_tile_menu_${tag.id}'),
                onSelected: (action) {
                  switch (action) {
                    case _TagAction.edit:
                      onEdit();
                    case _TagAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    key: ValueKey('tag_tile_edit_${tag.id}'),
                    value: _TagAction.edit,
                    child: Row(
                      children: [
                        Icon(AppIcons.edit, color: scheme.primary, size: 18),
                        const Gap(10),
                        const Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    key: ValueKey('tag_tile_delete_${tag.id}'),
                    value: _TagAction.delete,
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
              onTap: onEdit,
            ),
          );
        },
      ),
    );
  }
}

class _TagsSkeletonList extends StatelessWidget {
  const _TagsSkeletonList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const Gap(12),
        itemBuilder: (_, __) => AppCardSurface(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const CircleAvatar(radius: 16),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tag label', style: textTheme.titleSmall),
                      const Gap(6),
                      Text('Owner • Usage', style: textTheme.bodySmall),
                    ],
                  ),
                ),
                const Gap(8),
                const Chip(label: Text('3')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _TagAction { edit, delete }

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Gap(48),
        Icon(
          AppIcons.tag,
          size: 64,
          color: scheme.primary.withValues(alpha: 0.5),
        ),
        const Gap(16),
        Text(
          'No tags found',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        Text(
          'Create tags to organize and filter resources.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
