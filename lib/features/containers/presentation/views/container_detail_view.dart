import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/containers/containers_provider.dart';
import 'package:komodo_go/composition/resources/resource_name_resolver_provider.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/router/resource_routes.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/data/repositories/container_repository.dart';
import 'package:komodo_go/features/containers/presentation/providers/container_inspection_provider.dart';
import 'package:komodo_go/features/containers/presentation/widgets/container_card.dart';
import 'package:komodo_go/shared/logs/server_log_explorer.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';
import 'package:riverpod/misc.dart' show FutureProviderFamily;

class ContainerDetailView extends ConsumerStatefulWidget {
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
  ConsumerState<ContainerDetailView> createState() =>
      _ContainerDetailViewState();
}

class _ContainerDetailViewState extends ConsumerState<ContainerDetailView> {
  static const _tabLogs = 'logs';
  static const _tabInspect = 'inspect';

  final _tabsKey = GlobalKey<DetailTabScaffoldState>();
  String _activeTabId = _tabLogs;
  var _autoRefreshLogs = true;

  String get _container => Uri.decodeComponent(widget.containerIdOrName);

  @override
  Widget build(BuildContext context) {
    final serverId = widget.serverId;
    final container = _container;
    final itemAsync = ref.watch(
      _containerItemProviderFamily(
        _ContainerItemArgs(
          serverId: serverId,
          containerIdOrName: widget.containerIdOrName,
        ),
      ),
    );
    final inspectionAsync = ref.watch(
      containerInspectionProvider(
        serverIdOrName: serverId,
        containerIdOrName: container,
      ),
    );
    final resourceAsync = ref.watch(
      containerAssociatedResourceProvider(
        serverIdOrName: serverId,
        containerIdOrName: container,
      ),
    );
    ref.watch(containerActionsProvider);

    // While (re)loading, keep showing the item passed in from the list as
    // a placeholder instead of a skeleton.
    final item = itemAsync.asData?.value ?? widget.initialItem;
    final notFound = itemAsync.hasValue && itemAsync.value == null;

    final Widget headerContent;
    if (itemAsync.hasError && item == null) {
      headerContent = ErrorStateView.fromError(
        title: 'Failed to load container',
        error: itemAsync.error!,
        onRetry: () => ref.invalidate(containersProvider),
      );
    } else if (notFound) {
      headerContent = const _NotFound();
    } else if (item == null) {
      headerContent = const AppSkeletonCard();
    } else {
      headerContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, item, resourceAsync.asData?.value),
          const Gap(AppSpacing.md),
          _buildActionBar(context, item),
        ],
      );
    }

    return Scaffold(
      appBar: MainAppBar(
        title: item?.container.name ?? container,
        icon: AppIcons.containers,
        status: item == null ? null : _appBarStatus(item.container.state),
      ),
      body: DetailTabScaffold(
        key: _tabsKey,
        initialTabId: _tabLogs,
        onTabChanged: (id) => setState(() => _activeTabId = id),
        headerSlivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: headerContent,
            ),
          ),
        ],
        tabs: [
          DetailTabSpec(
            id: _tabLogs,
            label: 'Logs',
            icon: AppIcons.logs,
            body: DetailTabFillBody(
              child: ServerLogExplorer(
                key: ValueKey('container_log_explorer_$container'),
                fillHeight: true,
                autoRefresh: _autoRefreshLogs && _activeTabId == _tabLogs,
                onAutoRefreshChanged: (value) =>
                    setState(() => _autoRefreshLogs = value),
                loader: (request) async {
                  final repository = ref.read(containerRepositoryProvider);
                  if (repository == null) {
                    throw StateError('No active Komodo connection.');
                  }
                  final result = request.isSearch
                      ? await repository.searchServerLog(
                          serverIdOrName: serverId,
                          containerIdOrName: container,
                          terms: request.terms,
                          combinator: request.combinator,
                          invert: request.invert,
                          timestamps: request.timestamps,
                        )
                      : await repository.loadServerLog(
                          serverIdOrName: serverId,
                          containerIdOrName: container,
                          tail: request.tail,
                          timestamps: request.timestamps,
                        );
                  return result.fold(
                    (failure) => throw StateError(failure.displayMessage),
                    (log) => log,
                  );
                },
              ),
            ),
          ),
          DetailTabSpec(
            id: _tabInspect,
            label: 'Inspect',
            icon: AppIcons.eye,
            body: RefreshIndicator(
              onRefresh: () async {
                ref
                  ..invalidate(containersProvider)
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
              },
              child: DetailTabScrollView.box(
                scrollKey: PageStorageKey('container_${container}_inspect'),
                child: _ContainerInspectionPanel(
                  inspectionAsync: inspectionAsync,
                  onRetry: () => ref.invalidate(
                    containerInspectionProvider(
                      serverIdOrName: serverId,
                      containerIdOrName: container,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  MainAppBarStatus _appBarStatus(ContainerState state) {
    final name = state.name;
    return MainAppBarStatus(
      label: '${name[0].toUpperCase()}${name.substring(1)}',
      tone: switch (state) {
        ContainerState.running => PillTone.success,
        ContainerState.dead => PillTone.alert,
        ContainerState.restarting ||
        ContainerState.paused ||
        ContainerState.removing => PillTone.warning,
        _ => PillTone.neutral,
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ContainerOverviewItem item,
    ContainerAssociatedResource? resource,
  ) {
    final info = item.container;
    final image = info.image ?? '';
    final stats = info.stats;
    final ports =
        info.ports
            .map((port) => port.publicPort ?? port.privatePort)
            .where((port) => port > 0)
            .toSet()
            .toList()
          ..sort();

    DetailFact? linkedFact;
    if (resource != null) {
      final isStack = resource.type == ContainerResourceType.stack;
      final name = ref
          .watch(_linkedResourceNameProvider((resource.type, resource.id)))
          .asData
          ?.value;
      linkedFact = DetailFact(
        icon: isStack ? AppIcons.stacks : AppIcons.deployments,
        label: isStack ? 'Stack' : 'Deployment',
        value: (name ?? '').isNotEmpty ? name! : resource.id,
        onTap: () => context.push(
          resourceDetailRoute(
            isStack ? AppRoutes.stacks : AppRoutes.deployments,
            resource.id,
            name: name,
          ),
        ),
      );
    }

    return DetailResourceHeader(
      facts: [
        if (item.serverName.isNotEmpty)
          DetailFact(
            icon: AppIcons.server,
            label: 'Server',
            value: item.serverName,
            onTap: () => context.push(
              resourceDetailRoute(
                AppRoutes.servers,
                item.serverId,
                name: item.serverName,
              ),
            ),
          ),
        if (image.isNotEmpty)
          DetailFact(
            icon: AppIcons.package,
            label: 'Image',
            value: image,
            fullValue: image,
          ),
        ?linkedFact,
        if (info.networks.isNotEmpty)
          DetailFact(
            icon: AppIcons.network,
            label: 'Networks',
            value: info.networks.join(', '),
          ),
        if (ports.isNotEmpty)
          DetailFact(
            icon: AppIcons.plug,
            label: 'Ports',
            value: ports.join(', '),
          ),
      ],
      stats: [
        if (stats != null && stats.cpuPerc.trim().isNotEmpty)
          DetailStat(
            label: 'CPU',
            value: stats.cpuPerc,
            progress: stats.cpuPercentValue == null
                ? null
                : (stats.cpuPercentValue! / 100).clamp(0, 1),
          ),
        if (stats != null &&
            (stats.memUsage.trim().isNotEmpty ||
                stats.memPerc.trim().isNotEmpty))
          DetailStat(
            label: 'Memory',
            value: stats.memUsage.trim().isNotEmpty
                ? stats.memUsage
                : stats.memPerc,
            progress: stats.memPercentValue == null
                ? null
                : (stats.memPercentValue! / 100).clamp(0, 1),
          ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, ContainerOverviewItem item) {
    final state = item.container.state;
    final running = state == ContainerState.running;
    final paused = state == ContainerState.paused;
    final restarting = state == ContainerState.restarting;
    final canStart =
        state == ContainerState.exited ||
        state == ContainerState.created ||
        state == ContainerState.dead;
    final canRestart =
        running ||
        paused ||
        restarting ||
        state == ContainerState.exited ||
        state == ContainerState.created;
    final canStop = running || paused || restarting;
    final removing = state == ContainerState.removing;

    final ContainerAction? primaryAction;
    final String primaryLabel;
    final IconData primaryIcon;
    if (canStart) {
      primaryAction = ContainerAction.start;
      primaryLabel = 'Start';
      primaryIcon = AppIcons.play;
    } else if (paused) {
      primaryAction = ContainerAction.unpause;
      primaryLabel = 'Resume';
      primaryIcon = AppIcons.play;
    } else if (canRestart) {
      primaryAction = ContainerAction.restart;
      primaryLabel = 'Restart';
      primaryIcon = AppIcons.refresh;
    } else {
      primaryAction = null;
      primaryLabel = 'Start';
      primaryIcon = AppIcons.play;
    }

    VoidCallback call(ContainerAction action) =>
        () => _handleAction(item, action);

    return DetailActionBar(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      primary: DetailActionButton(
        label: primaryLabel,
        icon: primaryIcon,
        onPressed: primaryAction == null
            ? null
            : () => _handleAction(item, primaryAction!),
      ),
      moreGroups: resourceMenuGroups(
        lifecycle: [
          if (canStart && primaryAction != ContainerAction.start)
            ResourceMenuItems.start(call(ContainerAction.start)),
          if (paused && primaryAction != ContainerAction.unpause)
            ResourceMenuItems.unpause(call(ContainerAction.unpause)),
          if (running) ResourceMenuItems.pause(call(ContainerAction.pause)),
          if (canRestart && primaryAction != ContainerAction.restart)
            ResourceMenuItems.restart(call(ContainerAction.restart)),
          if (canStop) ResourceMenuItems.stop(call(ContainerAction.stop)),
        ],
        danger: [
          if (!removing)
            ResourceMenuItems.destroy(
              call(ContainerAction.remove),
              label: 'Remove',
            ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    ContainerOverviewItem item,
    ContainerAction action,
  ) async {
    final container = _container;
    final name = item.container.name.isEmpty ? container : item.container.name;

    if (action == ContainerAction.stop) {
      final confirmed = await confirmDestructive(
        context,
        title: 'Stop $name?',
        message:
            'This stops the container $name. A managed Stack or Deployment '
            'may start it again.',
        confirmLabel: 'Stop',
      );
      if (!confirmed || !mounted) return;
    }
    if (action == ContainerAction.remove) {
      final confirmed = await confirmDestructive(
        context,
        title: 'Remove container?',
        message:
            'This permanently removes $name. '
            'A managed Stack or Deployment may recreate it.',
        confirmLabel: 'Remove',
      );
      if (!confirmed || !mounted) return;
    }

    final serverId = widget.serverId;
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
    if (!mounted) return;
    AppSnackBar.show(
      context,
      success
          ? 'Action submitted. Check updates for the result.'
          : 'Action failed',
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

final FutureProviderFamily<String?, (ContainerResourceType, String)>
_linkedResourceNameProvider = FutureProvider.autoDispose
    .family<String?, (ContainerResourceType, String)>((ref, args) async {
      try {
        final resolver = ref.watch(composedResourceNameResolverProvider);
        return await resolver(
          ResourceRef(
            kind: args.$1 == ContainerResourceType.stack
                ? ResourceKind.stacks
                : ResourceKind.deployments,
            id: args.$2,
          ),
        );
      } on Object {
        return null;
      }
    });

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
                key: const PageStorageKey<String>(
                  'container_inspect_raw_expanded',
                ),
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
      error: (error, _) => ErrorStateView.fromError(
        title: 'Inspection unavailable',
        error: error,
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
