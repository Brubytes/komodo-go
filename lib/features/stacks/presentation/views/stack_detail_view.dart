import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/core/router/polling_route_aware_state.dart';
import 'package:komodo_go/core/router/shell_state_provider.dart';

import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/stacks/presentation/widgets/stack_card.dart';

/// View displaying detailed stack information.
class StackDetailView extends ConsumerStatefulWidget {
  const StackDetailView({
    required this.stackId,
    required this.stackName,
    super.key,
  });

  final String stackId;
  final String stackName;

  @override
  ConsumerState<StackDetailView> createState() => _StackDetailViewState();
}

class _StackDetailViewState extends PollingRouteAwareState<StackDetailView> {
  Timer? _logRefreshTimer;
  var _autoRefreshLogs = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _logRefreshTimer?.cancel();
    _logRefreshTimer = null;
    super.dispose();
  }

  @override
  void onVisibilityChanged() {
    if (!mounted) return;
    _syncLogPolling(isActiveTab: ref.read(mainShellIndexProvider) == 1);
    super.onVisibilityChanged();
  }

  void _startLogPolling() {
    _logRefreshTimer?.cancel();
    _logRefreshTimer = null;
    if (!_autoRefreshLogs) return;

    _logRefreshTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      ref.invalidate(stackLogProvider(widget.stackId));
    });
  }

  void _stopLogPolling() {
    _logRefreshTimer?.cancel();
    _logRefreshTimer = null;
  }

  void _syncLogPolling({required bool isActiveTab}) {
    if (shouldPoll(isActiveTab: isActiveTab, enabled: _autoRefreshLogs)) {
      _startLogPolling();
    } else {
      _stopLogPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActiveTab = ref.watch(mainShellIndexProvider) == 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncLogPolling(isActiveTab: isActiveTab);
    });

    final stackAsync = ref.watch(stackDetailProvider(widget.stackId));
    final servicesAsync = ref.watch(stackServicesProvider(widget.stackId));
    final logAsync = ref.watch(stackLogProvider(widget.stackId));
    final stacksListAsync = ref.watch(stacksProvider);
    final serversListAsync = ref.watch(serversProvider);
    final actionsState = ref.watch(stackActionsProvider);

    final scheme = Theme.of(context).colorScheme;

    StackListItem? listItem;
    final stacks = stacksListAsync.asData?.value;
    if (stacks != null) {
      for (final s in stacks) {
        if (s.id == widget.stackId) {
          listItem = s;
          break;
        }
      }
    }

    final services = servicesAsync.asData?.value;
    final serviceCount = services?.length;
    final updateCount = services?.where((e) => e.updateAvailable).length;

    String? serverNameForId(String serverId) {
      final servers = serversListAsync.asData?.value;
      if (servers == null || serverId.isEmpty) return null;
      for (final s in servers) {
        if (s.id == serverId) return s.name;
      }
      return null;
    }

    return Scaffold(
      appBar: MainAppBar(
        title: widget.stackName,
        icon: AppIcons.stacks,
        markColor: AppTokens.resourceStacks,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          PopupMenuButton<StackAction>(
            icon: const Icon(AppIcons.moreVertical),
            onSelected: (action) =>
                _handleAction(context, widget.stackId, action),
            itemBuilder: (context) => [
              komodoPopupMenuItem(
                value: StackAction.redeploy,
                icon: AppIcons.deployments,
                label: 'Redeploy',
                iconColor: scheme.primary,
              ),
              komodoPopupMenuItem(
                value: StackAction.pullImages,
                icon: AppIcons.download,
                label: 'Pull images',
                iconColor: scheme.primary,
              ),
              komodoPopupMenuItem(
                value: StackAction.restart,
                icon: AppIcons.refresh,
                label: 'Restart',
                iconColor: scheme.primary,
              ),
              komodoPopupMenuItem(
                value: StackAction.pause,
                icon: AppIcons.pause,
                label: 'Pause',
                iconColor: scheme.tertiary,
              ),
              komodoPopupMenuDivider(),
              komodoPopupMenuItem(
                value: StackAction.start,
                icon: AppIcons.play,
                label: 'Start',
                iconColor: scheme.secondary,
              ),
              komodoPopupMenuItem(
                value: StackAction.stop,
                icon: AppIcons.stop,
                label: 'Stop',
                iconColor: scheme.tertiary,
              ),
              komodoPopupMenuItem(
                value: StackAction.destroy,
                icon: AppIcons.delete,
                label: 'Destroy',
                destructive: true,
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref
                ..invalidate(stackDetailProvider(widget.stackId))
                ..invalidate(stackServicesProvider(widget.stackId))
                ..invalidate(stackLogProvider(widget.stackId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                stackAsync.when(
                  data: (stack) => stack != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StackHeroPanel(
                              stack: stack,
                              listItem: listItem,
                              serviceCount: serviceCount,
                              updateCount: updateCount,
                              serverName: serverNameForId(
                                stack.config.serverId,
                              ),
                            ),
                            const Gap(16),
                            DetailSection(
                              title: 'Config',
                              icon: AppIcons.settings,
                              child: _StackConfigContent(
                                config: stack.config,
                                serverName: serverNameForId(
                                  stack.config.serverId,
                                ),
                              ),
                            ),
                            const Gap(16),
                            DetailSection(
                              title: 'Deployment',
                              icon: AppIcons.deployments,
                              child: _StackDeploymentContent(info: stack.info),
                            ),
                          ],
                        )
                      : const _MessageSurface(message: 'Stack not found'),
                  loading: () => const _LoadingSurface(),
                  error: (error, _) =>
                      _MessageSurface(message: 'Error: $error'),
                ),
                const Gap(16),
                servicesAsync.when(
                  data: (services) => DetailSection(
                    title: 'Services',
                    icon: AppIcons.widgets,
                    child: services.isEmpty
                        ? const Text('No services found')
                        : Column(
                            children: [
                              for (final service in services) ...[
                                _StackServiceCard(service: service),
                                const Gap(12),
                              ],
                            ],
                          ),
                  ),
                  loading: () => const _LoadingSurface(),
                  error: (error, _) =>
                      _MessageSurface(message: 'Services unavailable: $error'),
                ),
                const Gap(16),
                logAsync.when(
                  data: (log) => DetailSection(
                    title: 'Logs',
                    icon: AppIcons.activity,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.refresh,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const Gap(6),
                        Switch(
                          value: _autoRefreshLogs,
                          onChanged: (value) {
                            setState(() => _autoRefreshLogs = value);
                            _syncLogPolling(
                              isActiveTab:
                                  ref.read(mainShellIndexProvider) == 1,
                            );
                          },
                        ),
                      ],
                    ),
                    child: _StackLogContent(log: log),
                  ),
                  loading: () => const _LoadingSurface(),
                  error: (error, _) =>
                      _MessageSurface(message: 'Logs unavailable: $error'),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: scheme.scrim.withValues(alpha: 0.25),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String stackId,
    StackAction action,
  ) async {
    final actions = ref.read(stackActionsProvider.notifier);
    if (action == StackAction.destroy) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Destroy stack?'),
          content: const Text(
            'This will run docker compose down and remove the stack containers. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Destroy'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final success = await switch (action) {
      StackAction.redeploy => actions.deploy(stackId),
      StackAction.pullImages => actions.pullImages(stackId),
      StackAction.restart => actions.restart(stackId),
      StackAction.pause => actions.pause(stackId),
      StackAction.start => actions.start(stackId),
      StackAction.stop => actions.stop(stackId),
      StackAction.destroy => actions.destroy(stackId),
    };

    if (success) {
      ref
        ..invalidate(stackDetailProvider(stackId))
        ..invalidate(stackServicesProvider(stackId))
        ..invalidate(stackLogProvider(stackId));
    }

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success
            ? 'Action completed successfully'
            : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }
}

class _StackHeroPanel extends StatelessWidget {
  const _StackHeroPanel({
    required this.stack,
    required this.listItem,
    required this.serviceCount,
    required this.updateCount,
    required this.serverName,
  });

  final KomodoStack stack;
  final StackListItem? listItem;
  final int? serviceCount;
  final int? updateCount;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final config = stack.config;
    final info = stack.info;

    final state = listItem?.info.state;
    final status = listItem?.info.status;
    final projectMissing = listItem?.info.projectMissing ?? false;

    final missingCount = info.missingFiles.length;
    final upToDate =
        info.latestHash != null && info.deployedHash == info.latestHash;

    return DetailHeroPanel(
      tintColor: scheme.primary,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stack.description.trim().isNotEmpty) ...[
            DetailIconInfoRow(
              icon: AppIcons.tag,
              label: 'Description',
              value: stack.description.trim(),
            ),
            const Gap(10),
          ],
          if (config.serverId.isNotEmpty) ...[
            DetailIconInfoRow(
              icon: AppIcons.server,
              label: 'Server',
              value: serverName ?? config.serverId,
            ),
            const Gap(10),
          ],
          if (status?.trim().isNotEmpty ?? false) ...[
            DetailIconInfoRow(
              icon: AppIcons.activity,
              label: 'Status',
              value: status!.trim(),
            ),
            const Gap(10),
          ],
          if (config.repo.isNotEmpty) ...[
            DetailIconInfoRow(
              icon: AppIcons.repos,
              label: 'Repo',
              value: config.branch.isNotEmpty
                  ? '${config.repo} (${config.branch})'
                  : config.repo,
            ),
            const Gap(10),
          ],
          if (config.runDirectory.isNotEmpty)
            DetailIconInfoRow(
              icon: AppIcons.package,
              label: 'Directory',
              value: config.runDirectory,
            ),
        ],
      ),
      metrics: [
        DetailMetricTileData(
          icon: _stateIcon(state),
          label: 'State',
          value: state?.displayName ?? '—',
          tone: _stateTone(state),
        ),
        DetailMetricTileData(
          icon: AppIcons.repos,
          label: 'Branch',
          value: config.branch.isNotEmpty ? config.branch : '—',
          tone: DetailMetricTone.neutral,
        ),
        DetailMetricTileData(
          icon: AppIcons.widgets,
          label: 'Services',
          value: serviceCount?.toString() ?? '—',
          tone: DetailMetricTone.neutral,
        ),
        DetailMetricTileData(
          icon: AppIcons.updateAvailable,
          label: 'Updates',
          value: updateCount?.toString() ?? '—',
          tone: (updateCount ?? 0) > 0
              ? DetailMetricTone.tertiary
              : DetailMetricTone.success,
        ),
        DetailMetricTileData(
          icon: AppIcons.warning,
          label: 'Missing',
          value: missingCount.toString(),
          tone: missingCount > 0
              ? DetailMetricTone.tertiary
              : DetailMetricTone.success,
        ),
        DetailMetricTileData(
          icon: upToDate ? AppIcons.ok : AppIcons.warning,
          label: 'Git',
          value: upToDate ? 'Up to date' : 'Out of date',
          tone: upToDate ? DetailMetricTone.success : DetailMetricTone.tertiary,
        ),
      ],
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (projectMissing)
            const StatusPill(
              label: 'Project missing',
              icon: AppIcons.warning,
              tone: PillTone.warning,
            ),
          for (final tag in stack.tags) TextPill(label: tag),
        ],
      ),
    );
  }

  IconData _stateIcon(StackState? state) {
    return switch (state) {
      StackState.running => AppIcons.ok,
      StackState.deploying || StackState.restarting => AppIcons.loading,
      StackState.unhealthy => AppIcons.error,
      StackState.stopped ||
      StackState.created ||
      StackState.down ||
      StackState.dead => AppIcons.stopped,
      StackState.paused => AppIcons.paused,
      StackState.removing => AppIcons.warning,
      _ => AppIcons.unknown,
    };
  }

  DetailMetricTone _stateTone(StackState? state) {
    return switch (state) {
      StackState.running => DetailMetricTone.success,
      StackState.deploying || StackState.restarting => DetailMetricTone.primary,
      StackState.unhealthy => DetailMetricTone.alert,
      StackState.stopped ||
      StackState.created ||
      StackState.down ||
      StackState.dead => DetailMetricTone.neutral,
      StackState.paused => DetailMetricTone.secondary,
      _ => DetailMetricTone.neutral,
    };
  }
}

class _StackConfigContent extends StatelessWidget {
  const _StackConfigContent({required this.config, required this.serverName});

  final StackConfig config;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final compose = config.fileContents.trim();
    final environment = config.environment.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill.onOff(
              isOn: config.autoPull,
              onLabel: 'Auto pull',
              offLabel: 'Manual pull',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.autoUpdate,
              onLabel: 'Auto update',
              offLabel: 'Manual update',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.pollForUpdates,
              onLabel: 'Polling on',
              offLabel: 'Polling off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.sendAlerts,
              onLabel: 'Alerts on',
              offLabel: 'Alerts off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.notifications,
            ),
          ],
        ),
        const Gap(14),
        DetailSubCard(
          title: 'Repository',
          icon: AppIcons.repos,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Repo',
                value: config.repo.isNotEmpty ? config.repo : '—',
              ),
              DetailKeyValueRow(
                label: 'Branch',
                value: config.branch.isNotEmpty ? config.branch : '—',
              ),
              DetailKeyValueRow(
                label: 'Commit',
                value: config.commit.isNotEmpty ? config.commit : '—',
                bottomPadding: 0,
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Paths',
          icon: AppIcons.package,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Project',
                value: config.projectName.isNotEmpty ? config.projectName : '—',
              ),
              DetailKeyValueRow(
                label: 'Clone path',
                value: config.clonePath.isNotEmpty ? config.clonePath : '—',
              ),
              DetailKeyValueRow(
                label: 'Run dir',
                value: config.runDirectory.isNotEmpty
                    ? config.runDirectory
                    : '—',
              ),
              DetailKeyValueRow(
                label: 'Env file',
                value: config.envFilePath.isNotEmpty ? config.envFilePath : '—',
                bottomPadding: 0,
              ),
            ],
          ),
        ),
        if (config.links.isNotEmpty ||
            config.additionalEnvFiles.isNotEmpty ||
            config.filePaths.isNotEmpty ||
            config.ignoreServices.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Extras',
            icon: AppIcons.widgets,
            child: Column(
              children: [
                if (config.links.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Links',
                    value: config.links.join('\n'),
                  ),
                if (config.additionalEnvFiles.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Extra env',
                    value: config.additionalEnvFiles.join('\n'),
                  ),
                if (config.filePaths.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Files',
                    value: config.filePaths.join('\n'),
                  ),
                if (config.ignoreServices.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Ignore',
                    value: config.ignoreServices.join(', '),
                    bottomPadding: 0,
                  ),
              ],
            ),
          ),
        ],
        if (config.serverId.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Server',
            icon: AppIcons.server,
            child: DetailKeyValueRow(
              label: 'Server',
              value: serverName ?? config.serverId,
              bottomPadding: 0,
            ),
          ),
        ],
        if (config.linkedRepo.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Linked repo',
            icon: AppIcons.repos,
            child: DetailKeyValueRow(
              label: 'Repo',
              value: config.linkedRepo,
              bottomPadding: 0,
            ),
          ),
        ],
        if (compose.isNotEmpty || environment.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Compose',
            icon: AppIcons.stacks,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (config.filePaths.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final path in config.filePaths)
                        TextPill(label: path),
                    ],
                  ),
                  const Gap(12),
                ],
                if (compose.isNotEmpty)
                  DetailCodeBlock(
                    code: compose,
                    language: DetailCodeLanguage.yaml,
                  )
                else
                  const Text('No compose contents available'),
                const Gap(12),
                Text(
                  'Environment variables',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(8),
                if (environment.isNotEmpty)
                  DetailCodeBlock(code: environment)
                else
                  const Text('No environment variables available'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StackDeploymentContent extends StatelessWidget {
  const _StackDeploymentContent({required this.info});

  final StackInfo info;

  @override
  Widget build(BuildContext context) {
    final latest = info.latestHash;
    final deployed = info.deployedHash;

    final upToDate = latest != null && deployed == latest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: upToDate ? 'Up to date' : 'Out of date',
              icon: upToDate ? AppIcons.ok : AppIcons.warning,
              tone: upToDate ? PillTone.success : PillTone.warning,
            ),
            if (info.missingFiles.isNotEmpty)
              StatusPill(
                label: '${info.missingFiles.length} missing files',
                icon: AppIcons.warning,
                tone: PillTone.warning,
              ),
          ],
        ),
        const Gap(14),
        DetailSubCard(
          title: 'Commits',
          icon: AppIcons.repos,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Latest',
                value: _shortHash(latest) ?? '—',
              ),
              if (info.latestMessage?.trim().isNotEmpty ?? false)
                DetailKeyValueRow(
                  label: 'Message',
                  value: info.latestMessage!.trim(),
                ),
              DetailKeyValueRow(
                label: 'Deployed',
                value: _shortHash(deployed) ?? '—',
              ),
              if (info.deployedMessage?.trim().isNotEmpty ?? false)
                DetailKeyValueRow(
                  label: 'Message',
                  value: info.deployedMessage!.trim(),
                  bottomPadding: 0,
                )
              else
                const DetailKeyValueRow(
                  label: 'Message',
                  value: '—',
                  bottomPadding: 0,
                ),
            ],
          ),
        ),
        if (info.missingFiles.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Missing files',
            icon: AppIcons.warning,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final f in info.missingFiles) TextPill(label: f)],
            ),
          ),
        ],
      ],
    );
  }

  String? _shortHash(String? value) {
    if (value == null) return null;
    final v = value.trim();
    if (v.isEmpty) return null;
    return v.length > 8 ? v.substring(0, 8) : v;
  }
}

class _StackServiceCard extends StatelessWidget {
  const _StackServiceCard({required this.service});

  final StackService service;

  @override
  Widget build(BuildContext context) {
    final container = service.container;
    final status = container?.status?.trim() ?? '';
    final state = container?.state.trim() ?? '';
    final hasUpdate = service.updateAvailable;

    return DetailSubCard(
      title: service.service,
      icon: hasUpdate ? AppIcons.updateAvailable : AppIcons.widgets,
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasUpdate)
                const StatusPill(
                  label: 'Update available',
                  icon: AppIcons.updateAvailable,
                  tone: PillTone.warning,
                )
              else
                const StatusPill(
                  label: 'Up to date',
                  icon: AppIcons.ok,
                  tone: PillTone.success,
                ),
              if (state.isNotEmpty) ValuePill(label: 'State', value: state),
              if (status.isNotEmpty) ValuePill(label: 'Status', value: status),
            ],
          ),
          if ((container?.image?.trim().isNotEmpty ?? false) ||
              (container?.name.trim().isNotEmpty ?? false)) ...[
            const Gap(12),
            if (container?.name.trim().isNotEmpty ?? false)
              DetailKeyValueRow(
                label: 'Container',
                value: container!.name.trim(),
              ),
            if (container?.image?.trim().isNotEmpty ?? false)
              DetailKeyValueRow(
                label: 'Image',
                value: container!.image!.trim(),
                bottomPadding: 0,
              ),
          ],
        ],
      ),
    );
  }
}

class _StackLogContent extends StatelessWidget {
  const _StackLogContent({required this.log});

  final StackLog? log;

  @override
  Widget build(BuildContext context) {
    final log = this.log;
    if (log == null) {
      return const Text('No logs available');
    }

    final output = [
      if (log.stdout.trim().isNotEmpty) log.stdout.trim(),
      if (log.stderr.trim().isNotEmpty) log.stderr.trim(),
    ].join('\n');

    final duration = (log.endTs > 0 && log.startTs > 0)
        ? Duration(milliseconds: log.endTs - log.startTs)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: log.success ? 'Success' : 'Failed',
              icon: log.success ? AppIcons.ok : AppIcons.error,
              tone: log.success ? PillTone.success : PillTone.alert,
            ),
            if (duration != null)
              ValuePill(label: 'Duration', value: '${duration.inSeconds}s'),
          ],
        ),
        const Gap(14),
        if (log.command.isNotEmpty) ...[
          DetailKeyValueRow(label: 'Command', value: log.command),
          const Gap(10),
        ],
        DetailCodeBlock(code: output.isNotEmpty ? output : 'No output'),
      ],
    );
  }
}

class _LoadingSurface extends StatelessWidget {
  const _LoadingSurface();

  @override
  Widget build(BuildContext context) {
    return const DetailSurface(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MessageSurface extends StatelessWidget {
  const _MessageSurface({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(child: Text(message));
  }
}
