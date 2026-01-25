import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pill_list.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

import 'package:komodo_go/features/alerters/data/models/alerter_list_item.dart';
import 'package:komodo_go/features/alerters/presentation/providers/alerters_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AlertersView extends ConsumerWidget {
  const AlertersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertersAsync = ref.watch(alertersProvider);
    final actionsState = ref.watch(alerterActionsProvider);

    return Scaffold(
      appBar: const MainAppBar(
        title: 'Alerters',
        icon: AppIcons.notifications,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(alertersProvider.notifier).refresh(),
            child: alertersAsync.when(
              data: (items) {
                if (items.isEmpty) return const _EmptyState();

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Gap(12),
                  itemBuilder: (context, index) => AppFadeSlide(
                    delay: AppMotion.stagger(index),
                    play: index < 10,
                    child: _AlerterTile(item: items[index]),
                  ),
                );
              },
              loading: () => const _AlertersSkeletonList(),
              error: (error, _) => ErrorStateView(
                title: 'Failed to load alerters',
                message: error.toString(),
                onRetry: () => ref.invalidate(alertersProvider),
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

class _AlerterTile extends ConsumerWidget {
  const _AlerterTile({required this.item});

  final AlerterListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final info = item.info;

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('${AppRoutes.komodoAlerters}/${item.id}'),
          borderRadius: cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.secondary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        AppIcons.notifications,
                        color: scheme.secondary,
                        size: 18,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Gap(2),
                          Text(
                            info.endpointType,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: info.enabled,
                      onChanged: (value) async {
                        final ok = await ref
                            .read(alerterActionsProvider.notifier)
                            .setEnabled(id: item.id, enabled: value);

                        if (!context.mounted) return;
                        AppSnackBar.show(
                          context,
                          ok ? 'Alerter updated' : 'Failed to update alerter',
                          tone: ok
                              ? AppSnackBarTone.success
                              : AppSnackBarTone.error,
                        );
                      },
                    ),
                    PopupMenuButton<_AlerterAction>(
                      onSelected: (action) async {
                        switch (action) {
                          case _AlerterAction.edit:
                            await context.push(
                              '${AppRoutes.komodoAlerters}/${item.id}',
                            );
                            return;
                          case _AlerterAction.test:
                            await _test(context, ref);
                            return;
                          case _AlerterAction.rename:
                            await _rename(context, ref);
                            return;
                          case _AlerterAction.delete:
                            await _delete(context, ref);
                            return;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _AlerterAction.edit,
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
                          value: _AlerterAction.test,
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.activity,
                                color: scheme.primary,
                                size: 18,
                              ),
                              const Gap(10),
                              const Text('Test'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: _AlerterAction.rename,
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.edit,
                                color: scheme.primary,
                                size: 18,
                              ),
                              const Gap(10),
                              const Text('Rename'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: _AlerterAction.delete,
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
                  ],
                ),
                const Gap(10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.template) const TextPill(label: 'Template'),
                    if (info.endpointType.trim().isNotEmpty)
                      TextPill(label: info.endpointType),
                  ],
                ),
                if (item.tags.isNotEmpty) ...[
                  const Gap(10),
                  DetailPillList(items: item.tags, maxItems: 6),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _test(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(alerterActionsProvider.notifier)
        .test(idOrName: item.id);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Test triggered' : 'Failed to trigger test',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: item.name);
    final nextName = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename alerter'),
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
        .read(alerterActionsProvider.notifier)
        .rename(id: item.id, name: nextName);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Alerter renamed' : 'Failed to rename alerter',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete alerter'),
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
        .read(alerterActionsProvider.notifier)
        .delete(id: item.id);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Alerter deleted' : 'Failed to delete alerter',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}

class _AlertersSkeletonList extends StatelessWidget {
  const _AlertersSkeletonList();

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 18),
                    const Gap(10),
                    Expanded(
                      child: Text('Alerter name', style: textTheme.titleSmall),
                    ),
                    const Gap(8),
                    const CircleAvatar(radius: 6),
                  ],
                ),
                const Gap(10),
                Text('Endpoint • Level • Targets', style: textTheme.bodySmall),
                const Gap(10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: const [
                    Chip(label: Text('Enabled')),
                    Chip(label: Text('Alerts 5')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _AlerterAction { edit, test, rename, delete }

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
          AppIcons.notifications,
          size: 64,
          color: scheme.primary.withValues(alpha: 0.5),
        ),
        const Gap(16),
        Text(
          'No alerters found',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        Text(
          'Create and configure alerters in the Komodo web interface.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
