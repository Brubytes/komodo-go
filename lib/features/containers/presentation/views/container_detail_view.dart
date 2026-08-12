import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/containers/containers_provider.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/data/repositories/container_repository.dart';
import 'package:komodo_go/features/containers/presentation/providers/container_inspection_provider.dart';
import 'package:komodo_go/features/containers/presentation/widgets/container_card.dart';
import 'package:komodo_go/shared/logs/server_log_explorer.dart';
import 'package:riverpod/misc.dart' show FutureProviderFamily;

class ContainerDetailView extends ConsumerWidget {
  const ContainerDetailView({
    required this.serverId,
    required this.containerIdOrName,
    required this.initialItem,
    super.key,
  });

  final String serverId;
  final String containerIdOrName;
  final ContainerOverviewItem? initialItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(
      _containerItemProviderFamily(
        _ContainerItemArgs(
          serverId: serverId,
          containerIdOrName: containerIdOrName,
        ),
      ),
    );
    final decodedContainerIdOrName = Uri.decodeComponent(containerIdOrName);
    final inspectionAsync = ref.watch(
      containerInspectionProvider(
        serverIdOrName: serverId,
        containerIdOrName: decodedContainerIdOrName,
      ),
    );
    final resourceAsync = ref.watch(
      containerAssociatedResourceProvider(
        serverIdOrName: serverId,
        containerIdOrName: decodedContainerIdOrName,
      ),
    );
    ref.watch(containerActionsProvider);
    final initialItem = this.initialItem;
    final currentItem = itemAsync.asData?.value ?? initialItem;
    final itemContent = itemAsync.when(
      data: (item) => item == null
          ? const _NotFound()
          : ContainerCard(
              item: item,
              onAction: (action) => _handleAction(
                context,
                ref,
                item,
                action,
                decodedContainerIdOrName,
              ),
            ),
      // While (re)loading, keep showing the item passed in from the list as
      // a placeholder instead of a skeleton.
      loading: () => initialItem == null
          ? const AppSkeletonCard()
          : ContainerCard(
              item: initialItem,
              onAction: (action) => _handleAction(
                context,
                ref,
                initialItem,
                action,
                decodedContainerIdOrName,
              ),
            ),
      error: (error, stack) => _ErrorState(
        title: 'Failed to load container',
        message: error.toString(),
        onRetry: () => ref.invalidate(containersProvider),
      ),
    );
    final logContent = ServerLogExplorer(
      key: ValueKey('container_log_explorer_$decodedContainerIdOrName'),
      loader: (request) async {
        final repository = ref.read(containerRepositoryProvider);
        if (repository == null) {
          throw StateError('No active Komodo connection.');
        }
        final result = request.isSearch
            ? await repository.searchServerLog(
                serverIdOrName: serverId,
                containerIdOrName: decodedContainerIdOrName,
                terms: request.terms,
                combinator: request.combinator,
                invert: request.invert,
                timestamps: request.timestamps,
              )
            : await repository.loadServerLog(
                serverIdOrName: serverId,
                containerIdOrName: decodedContainerIdOrName,
                tail: request.tail,
                timestamps: request.timestamps,
              );
        return result.fold(
          (failure) => throw StateError(failure.displayMessage),
          (log) => log,
        );
      },
    );
    final inspectionContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AssociatedResourcePanel(
          resourceAsync: resourceAsync,
          onOpen: (resource) {
            final base = resource.type == ContainerResourceType.stack
                ? AppRoutes.stacks
                : AppRoutes.deployments;
            unawaited(context.push('$base/${resource.id}'));
          },
        ),
        const Gap(16),
        _ContainerInspectionPanel(
          inspectionAsync: inspectionAsync,
          onRetry: () => ref.invalidate(
            containerInspectionProvider(
              serverIdOrName: serverId,
              containerIdOrName: decodedContainerIdOrName,
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: const MainAppBar(title: 'Container', icon: AppIcons.containers),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(containersProvider)
            ..invalidate(
              containerInspectionProvider(
                serverIdOrName: serverId,
                containerIdOrName: decodedContainerIdOrName,
              ),
            )
            ..invalidate(
              containerAssociatedResourceProvider(
                serverIdOrName: serverId,
                containerIdOrName: decodedContainerIdOrName,
              ),
            );
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      itemContent,
                      if (currentItem != null) ...[
                        const Gap(16),
                        inspectionContent,
                      ],
                      const Gap(16),
                      logContent,
                    ],
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              itemContent,
                              if (currentItem != null) ...[
                                const Gap(16),
                                inspectionContent,
                              ],
                            ],
                          ),
                        ),
                        const Gap(16),
                        Expanded(flex: 6, child: logContent),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    ContainerOverviewItem item,
    ContainerAction action,
    String container,
  ) async {
    if (action == ContainerAction.remove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remove container?'),
          content: Text(
            'This permanently removes ${item.container.name}. '
            'A managed Stack or Deployment may recreate it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    final actions = ref.read(containerActionsProvider.notifier);
    final success = await switch (action) {
      ContainerAction.start => actions.start(
        serverIdOrName: serverId,
        containerIdOrName: container,
      ),
      ContainerAction.restart => actions.restart(
        serverIdOrName: serverId,
        containerIdOrName: container,
      ),
      ContainerAction.pause => actions.pause(
        serverIdOrName: serverId,
        containerIdOrName: container,
      ),
      ContainerAction.unpause => actions.unpause(
        serverIdOrName: serverId,
        containerIdOrName: container,
      ),
      ContainerAction.stop => actions.stop(
        serverIdOrName: serverId,
        containerIdOrName: container,
      ),
      ContainerAction.remove => actions.remove(
        serverIdOrName: serverId,
        containerIdOrName: container,
      ),
    };
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      success ? 'Action completed successfully' : 'Action failed',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
    if (success) {
      ref
        ..invalidate(
          containerInspectionProvider(
            serverIdOrName: serverId,
            containerIdOrName: container,
          ),
        )
        ..invalidate(
          containerAssociatedResourceProvider(
            serverIdOrName: serverId,
            containerIdOrName: container,
          ),
        );
    }
  }
}

class _AssociatedResourcePanel extends StatelessWidget {
  const _AssociatedResourcePanel({
    required this.resourceAsync,
    required this.onOpen,
  });

  final AsyncValue<ContainerAssociatedResource?> resourceAsync;
  final ValueChanged<ContainerAssociatedResource> onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCardSurface(
      child: resourceAsync.when(
        data: (resource) {
          if (resource == null) {
            return const Text('Not associated with a Stack or Deployment.');
          }
          final label = resource.type == ContainerResourceType.stack
              ? 'Stack'
              : 'Deployment';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              resource.type == ContainerResourceType.stack
                  ? AppIcons.stacks
                  : AppIcons.deployments,
            ),
            title: Text('Managed by $label'),
            subtitle: Text(resource.id),
            trailing: const Icon(AppIcons.chevron),
            onTap: () => onOpen(resource),
          );
        },
        loading: () => const AppInlineSkeleton(),
        error: (error, _) => Text('Association unavailable: $error'),
      ),
    );
  }
}

class _ContainerInspectionPanel extends StatelessWidget {
  const _ContainerInspectionPanel({
    required this.inspectionAsync,
    required this.onRetry,
  });

  final AsyncValue<ContainerInspection?> inspectionAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return inspectionAsync.when(
      data: (inspection) {
        if (inspection == null) return const _NotFound();
        return DetailSection(
          title: 'Inspect',
          icon: AppIcons.eye,
          child: Column(
            children: [
              DetailKeyValueRow(label: 'ID', value: inspection.id ?? '—'),
              DetailKeyValueRow(
                label: 'Created',
                value: inspection.created ?? '—',
              ),
              DetailKeyValueRow(
                label: 'Platform / driver',
                value:
                    '${inspection.platform ?? '—'} / ${inspection.driver ?? '—'}',
              ),
              DetailKeyValueRow(
                label: 'Command',
                value: [inspection.path, ...inspection.args]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' '),
              ),
              DetailKeyValueRow(
                label: 'Restart count',
                value: inspection.restartCount?.toString() ?? '—',
              ),
              if (inspection.mounts.isNotEmpty) ...[
                const Gap(8),
                DetailSubCard(
                  title: 'Mounts (${inspection.mounts.length})',
                  icon: AppIcons.hardDrive,
                  child: Column(
                    children: [
                      for (final mount in inspection.mounts)
                        DetailKeyValueRow(
                          label: mount['destination'] as String? ?? 'Mount',
                          value:
                              mount['source'] as String? ??
                              mount['name'] as String? ??
                              '—',
                        ),
                    ],
                  ),
                ),
              ],
              const Gap(12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Raw Docker inspection'),
                children: [
                  DetailCodeBlock(
                    code: const JsonEncoder.withIndent('  ').convert(
                      inspection.raw,
                    ),
                    tabletMaxHeight: 520,
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const AppSkeletonCard(),
      error: (error, _) => _ErrorState(
        title: 'Inspection unavailable',
        message: error.toString(),
        onRetry: onRetry,
      ),
    );
  }
}

final FutureProviderFamily<ContainerOverviewItem?, _ContainerItemArgs>
_containerItemProviderFamily = FutureProvider.autoDispose
    .family<ContainerOverviewItem?, _ContainerItemArgs>((ref, args) async {
      final result = await ref.watch(containersProvider.future);

      final normalized = Uri.decodeComponent(args.containerIdOrName);
      for (final item in result.items) {
        if (item.serverId != args.serverId) continue;
        final id = item.container.id;
        if (id != null && id == normalized) return item;
        if (item.container.name == normalized) return item;
      }

      return null;
    });

@immutable
class _ContainerItemArgs {
  const _ContainerItemArgs({
    required this.serverId,
    required this.containerIdOrName,
  });

  final String serverId;
  final String containerIdOrName;

  @override
  bool operator ==(Object other) {
    return other is _ContainerItemArgs &&
        other.serverId == serverId &&
        other.containerIdOrName == containerIdOrName;
  }

  @override
  int get hashCode => Object.hash(serverId, containerIdOrName);
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return const AppCardSurface(
      child: Text('Container not found.'),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap(8),
          Text(message),
          const Gap(12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onRetry, child: const Text('Retry')),
          ),
        ],
      ),
    );
  }
}
