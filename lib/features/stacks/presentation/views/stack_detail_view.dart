import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/polling_route_aware_state.dart';
import 'package:komodo_go/core/router/shell_state_provider.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/stacks/presentation/views/stack_detail/stack_detail_sections.dart';
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

class _StackDetailViewState extends PollingRouteAwareState<StackDetailView>
    with DetailDirtySnackBarMixin<StackDetailView> {
  Timer? _logRefreshTimer;
  var _autoRefreshLogs = true;
  final _configEditorKey = GlobalKey<StackConfigEditorContentState>();

  var _configSaveInFlight = false;

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
    final reposListAsync = ref.watch(reposProvider);
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

    final servers = serversListAsync.asData?.value ?? const [];
    final repos = reposListAsync.asData?.value ?? const [];

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
                            StackHeroPanel(
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
                              child: StackConfigEditorContent(
                                key: _configEditorKey,
                                initialConfig: stack.config,
                                servers: servers,
                                repos: repos,
                                onDirtyChanged: (dirty) {
                                  syncDirtySnackBar(
                                    dirty: dirty,
                                    onDiscard: () => _discardConfig(stack),
                                    onSave: () => _saveConfig(stack: stack),
                                    saveEnabled: !_configSaveInFlight,
                                  );
                                },
                              ),
                            ),
                            const Gap(16),
                            DetailSection(
                              title: 'Deployment',
                              icon: AppIcons.deployments,
                              child: StackDeploymentContent(info: stack.info),
                            ),
                          ],
                        )
                      : const StackMessageSurface(message: 'Stack not found'),
                  loading: () => const StackLoadingSurface(),
                  error: (error, _) =>
                      StackMessageSurface(message: 'Error: $error'),
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
                                StackServiceCard(service: service),
                                const Gap(12),
                              ],
                            ],
                          ),
                  ),
                  loading: () => const StackLoadingSurface(),
                  error: (error, _) => StackMessageSurface(
                    message: 'Services unavailable: $error',
                  ),
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
                    child: StackLogContent(log: log),
                  ),
                  loading: () => const StackLoadingSurface(),
                  error: (error, _) =>
                      StackMessageSurface(message: 'Logs unavailable: $error'),
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

  void _discardConfig(KomodoStack stack) {
    _configEditorKey.currentState?.resetTo(stack.config);
    hideDirtySnackBar();
  }

  Future<void> _saveConfig({required KomodoStack stack}) async {
    if (_configSaveInFlight) return;

    final draft = _configEditorKey.currentState;
    if (draft == null) {
      AppSnackBar.show(
        context,
        'Editor not ready. Please try again.',
        tone: AppSnackBarTone.error,
      );
      return;
    }

    final partialConfig = draft.buildPartialConfigParams();
    if (partialConfig.isEmpty) {
      hideDirtySnackBar();
      return;
    }

    final actions = ref.read(stackActionsProvider.notifier);
    setState(() => _configSaveInFlight = true);
    final updated = await actions.updateStackConfig(
      stackId: stack.id,
      partialConfig: partialConfig,
    );
    if (!mounted) return;
    setState(() => _configSaveInFlight = false);

    if (updated != null) {
      ref
        ..invalidate(stackDetailProvider(stack.id))
        ..invalidate(stacksProvider);

      _configEditorKey.currentState?.resetTo(updated.config);
      hideDirtySnackBar();
      AppSnackBar.show(context, 'Stack updated', tone: AppSnackBarTone.success);
      return;
    }

    final err = ref.read(stackActionsProvider).asError?.error;
    AppSnackBar.show(
      context,
      err != null ? 'Failed: $err' : 'Failed to update stack',
      tone: AppSnackBarTone.error,
    );

    reShowDirtySnackBarIfStillDirty(
      isStillDirty: () {
        return _configEditorKey.currentState
                ?.buildPartialConfigParams()
                .isNotEmpty ??
            false;
      },
      onDiscard: () => _discardConfig(stack),
      onSave: () => _saveConfig(stack: stack),
      saveEnabled: !_configSaveInFlight,
    );
  }
}
