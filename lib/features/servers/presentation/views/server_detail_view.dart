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
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/servers/presentation/views/server_detail/server_detail_sections.dart';

/// View displaying detailed server information.
class ServerDetailView extends ConsumerStatefulWidget {
  const ServerDetailView({
    required this.serverId,
    required this.serverName,
    this.manageGroups = const <DetailActionGroup>[],
    super.key,
  });

  final String serverId;
  final String serverName;

  /// Extra "Manage" groups appended to the More menu (metadata, copy, ...).
  final List<DetailActionGroup> manageGroups;

  @override
  ConsumerState<ServerDetailView> createState() => _ServerDetailViewState();
}

class _ServerDetailViewState extends PollingRouteAwareState<ServerDetailView>
    with DetailDirtySnackBarMixin<ServerDetailView> {
  static const _tabStats = 'stats';
  static const _tabConfig = 'config';
  static const _tabSystem = 'system';

  String _currentTabId = _tabStats;
  var _dirty = false;
  Timer? _statsRefreshTimer;
  ProviderSubscription<AsyncValue<SystemStats?>>? _statsSubscription;
  final _configEditorKey = GlobalKey<ServerConfigEditorContentState>();
  var _configSaveInFlight = false;
  ServerStatsGranularity _historyGranularity = ServerStatsGranularity.oneMinute;
  bool _useFixedPercentScale = true;

  DateTime? _previousSampleTs;
  double? _previousIngressBytes;
  double? _previousEgressBytes;
  double? _ingressBytesPerSecond;
  double? _egressBytesPerSecond;

  @override
  void initState() {
    super.initState();

    _statsSubscription = ref.listenManual<AsyncValue<SystemStats?>>(
      serverStatsProvider(widget.serverId),
      (previous, next) {
        final stats = next.asData?.value;
        if (stats == null) return;
        _recordSample(stats);
      },
    );
  }

  @override
  void dispose() {
    _statsRefreshTimer?.cancel();
    _statsRefreshTimer = null;
    _statsSubscription?.close();
    _statsSubscription = null;
    super.dispose();
  }

  @override
  void onVisibilityChanged() {
    if (!mounted) return;
    _syncStatsTimer(isShellTabActive: ref.read(mainShellIndexProvider) == 1);
    super.onVisibilityChanged();
  }

  void _onTabChanged(String id) {
    if (!mounted) return;
    _currentTabId = id;
    _syncStatsTimer(isShellTabActive: ref.read(mainShellIndexProvider) == 1);
  }

  void _startStatsTimer() {
    if (_statsRefreshTimer != null) return;
    _statsRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!shouldRunPollTick()) return;
      unawaited(
        ref.read(serverStatsProvider(widget.serverId).notifier).pollRefresh(),
      );
    });
    unawaited(
      ref.read(serverStatsProvider(widget.serverId).notifier).pollRefresh(),
    );
  }

  void _stopStatsTimer() {
    _statsRefreshTimer?.cancel();
    _statsRefreshTimer = null;
  }

  void _syncStatsTimer({required bool isShellTabActive}) {
    final isStatsTabActive = _currentTabId == _tabStats;
    final isActiveTab = isShellTabActive && isStatsTabActive;
    if (shouldPoll(isActiveTab: isActiveTab)) {
      _startStatsTimer();
    } else {
      _stopStatsTimer();
    }
  }

  void _recordSample(SystemStats stats) {
    final now = DateTime.now();
    final previousSampleTs = _previousSampleTs;
    final previousIngressBytes = _previousIngressBytes;
    final previousEgressBytes = _previousEgressBytes;

    _previousSampleTs = now;
    _previousIngressBytes = stats.networkIngressBytes;
    _previousEgressBytes = stats.networkEgressBytes;

    double ingressBps = 0;
    double egressBps = 0;
    if (previousSampleTs != null &&
        previousIngressBytes != null &&
        previousEgressBytes != null) {
      final dtSeconds =
          now.difference(previousSampleTs).inMilliseconds.toDouble() / 1000.0;

      if (dtSeconds > 0) {
        final ingressDelta = stats.networkIngressBytes - previousIngressBytes;
        final egressDelta = stats.networkEgressBytes - previousEgressBytes;

        if (ingressDelta >= 0 && egressDelta >= 0) {
          ingressBps = ingressDelta / dtSeconds;
          egressBps = egressDelta / dtSeconds;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _ingressBytesPerSecond = ingressBps;
      _egressBytesPerSecond = egressBps;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isActiveTab = ref.watch(mainShellIndexProvider) == 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncStatsTimer(isShellTabActive: isActiveTab);
    });

    final serverAsync = ref.watch(serverDetailProvider(widget.serverId));
    final statsAsync = ref.watch(serverStatsProvider(widget.serverId));
    final historyAsync = ref.watch(
      serverStatsHistoryProvider(widget.serverId, _historyGranularity),
    );
    final processesAsync = ref.watch(serverProcessesProvider(widget.serverId));
    final systemInfoAsync = ref.watch(
      serverSystemInformationProvider(widget.serverId),
    );
    final serversListAsync = ref.watch(serversProvider);
    ref.watch(serverActionsProvider);

    final server = serverAsync.asData?.value;
    final stats = statsAsync.asData?.value;
    final systemInformation = systemInfoAsync.asData?.value;

    Server? listServer;
    final servers = serversListAsync.asData?.value;
    if (servers != null) {
      for (final s in servers) {
        if (s.id == widget.serverId) {
          listServer = s;
          break;
        }
      }
    }

    return UnsavedChangesGuard(
      dirty: _dirty,
      onDiscarded: hideDirtySnackBar,
      child: Scaffold(
        appBar: MainAppBar(
          title: widget.serverName,
          icon: AppIcons.server,
          markColor: AppTokens.resourceServers,
          markUseGradient: true,
          centerTitle: true,
          status: serverAppBarStatus(
            server: server,
            listServer: listServer,
          ),
        ),
        body: DetailTabScaffold(
          initialTabId: _tabStats,
          onTabChanged: _onTabChanged,
          headerSlivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ServerHeader(
                      server: server ?? listServer,
                      listServer: listServer,
                      stats: stats,
                      systemInformation: systemInformation,
                      ingressBytesPerSecond: _ingressBytesPerSecond,
                      egressBytesPerSecond: _egressBytesPerSecond,
                    ),
                    const Gap(AppSpacing.md),
                    DetailActionBar(
                      // The servers API client exposes no execute endpoints
                      // (prune, stop containers, ...), so the only action is
                      // refreshing what is shown.
                      primary: DetailActionButton(
                        label: 'Refresh',
                        icon: AppIcons.refresh,
                        onPressed: _refreshAll,
                      ),
                      moreGroups: widget.manageGroups,
                    ),
                  ],
                ),
              ),
            ),
          ],
          tabs: [
            DetailTabSpec(
              id: _tabStats,
              label: 'Stats',
              icon: AppIcons.activity,
              body: RefreshIndicator(
                onRefresh: () async => _refreshAll(),
                child: DetailTabScrollView.box(
                  scrollKey: PageStorageKey('server_${widget.serverId}_stats'),
                  child: historyAsync.when(
                    data: (history) => DetailSurface(
                      child: StatsHistoryContent(
                        history: history?.stats ?? const [],
                        latestStats: stats,
                        granularity: _historyGranularity,
                        useFixedPercentScale: _useFixedPercentScale,
                        onGranularityChanged: (value) {
                          setState(() => _historyGranularity = value);
                        },
                        onScaleChanged: (value) {
                          setState(() => _useFixedPercentScale = value);
                        },
                      ),
                    ),
                    loading: () => const ServerLoadingCard(),
                    error: (error, _) => ServerErrorCard(
                      title: 'Historical stats unavailable',
                      error: error,
                      onRetry: () => ref.invalidate(
                        serverStatsHistoryProvider(
                          widget.serverId,
                          _historyGranularity,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            DetailTabSpec(
              id: _tabConfig,
              label: 'Config',
              icon: AppIcons.bolt,
              body: RefreshIndicator(
                onRefresh: () async => _refreshAll(),
                child: DetailTabScrollView.box(
                  scrollKey: PageStorageKey('server_${widget.serverId}_config'),
                  child: serverAsync.when(
                    data: (server) => server?.config != null
                        ? ServerConfigEditorContent(
                            key: _configEditorKey,
                            initialConfig: server!.config!,
                            onDirtyChanged: (dirty) {
                              _dirty = dirty;
                              syncDirtySnackBar(
                                dirty: dirty,
                                onDiscard: () => _discardConfig(server),
                                onSave: () => _saveConfig(server: server),
                                saveEnabled: !_configSaveInFlight,
                                saving: _configSaveInFlight,
                              );
                            },
                          )
                        : const ServerMessageCard(
                            message: 'No config available',
                          ),
                    loading: () => const ServerLoadingCard(),
                    error: (error, _) => ServerErrorCard(
                      title: 'Could not load config',
                      error: error,
                      onRetry: () => ref.invalidate(
                        serverDetailProvider(widget.serverId),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            DetailTabSpec(
              id: _tabSystem,
              label: 'System',
              icon: AppIcons.cpu,
              body: RefreshIndicator(
                onRefresh: () async {
                  _refreshAll();
                  ref.invalidate(serverProcessesProvider(widget.serverId));
                },
                child: DetailTabScrollView.box(
                  scrollKey: PageStorageKey('server_${widget.serverId}_system'),
                  child: systemInfoAsync.when(
                    data: (info) => info != null
                        ? DetailSurface(
                            child: Column(
                              children: [
                                ServerSystemInfoContent(info: info),
                                const Gap(AppSpacing.md),
                                processesAsync.when(
                                  data: (processes) => SystemProcessesContent(
                                    processes: processes,
                                  ),
                                  loading: () => const ServerLoadingCard(),
                                  error: (error, _) => ServerErrorCard(
                                    title: 'Processes unavailable',
                                    error: error,
                                    onRetry: () => ref.invalidate(
                                      serverProcessesProvider(
                                        widget.serverId,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const ServerMessageCard(
                            message: 'System info unavailable',
                          ),
                    loading: () => const ServerLoadingCard(),
                    error: (error, _) => ServerErrorCard(
                      title: 'System info unavailable',
                      error: error,
                      onRetry: () => ref.invalidate(
                        serverSystemInformationProvider(widget.serverId),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshAll() {
    ref
      ..invalidate(serverDetailProvider(widget.serverId))
      ..invalidate(serverSystemInformationProvider(widget.serverId))
      ..invalidate(serverStatsProvider(widget.serverId))
      ..invalidate(
        serverStatsHistoryProvider(widget.serverId, _historyGranularity),
      );
  }

  void _discardConfig(Server server) {
    _configEditorKey.currentState?.resetTo(server.config!);
    hideDirtySnackBar();
  }

  Future<void> _saveConfig({required Server server}) async {
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

    final actions = ref.read(serverActionsProvider.notifier);
    setState(() => _configSaveInFlight = true);
    syncDirtySnackBar(
      dirty: true,
      onDiscard: () => _discardConfig(server),
      onSave: () => _saveConfig(server: server),
      saving: true,
      saveEnabled: false,
    );
    final updated = await actions.updateServerConfig(
      serverId: server.id,
      partialConfig: partialConfig,
    );
    if (!mounted) return;
    setState(() => _configSaveInFlight = false);

    if (updated != null) {
      ref
        ..invalidate(serverDetailProvider(server.id))
        ..invalidate(serversProvider);

      _configEditorKey.currentState?.resetTo(updated.config!);
      _dirty = false;
      hideDirtySnackBar();
      AppSnackBar.show(
        context,
        'Server updated',
        tone: AppSnackBarTone.success,
      );
      return;
    }

    final err = ref.read(serverActionsProvider).asError?.error;
    AppSnackBar.show(
      context,
      err != null ? 'Failed: $err' : 'Failed to update server',
      tone: AppSnackBarTone.error,
    );

    reShowDirtySnackBarIfStillDirty(
      isStillDirty: () {
        return _configEditorKey.currentState
                ?.buildPartialConfigParams()
                .isNotEmpty ??
            false;
      },
      onDiscard: () => _discardConfig(server),
      onSave: () => _saveConfig(server: server),
      saveEnabled: !_configSaveInFlight,
    );
  }
}
