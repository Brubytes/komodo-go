import 'dart:async';

import 'package:flutter/material.dart';
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
    super.key,
  });

  final String serverId;
  final String serverName;

  @override
  ConsumerState<ServerDetailView> createState() => _ServerDetailViewState();
}

class _ServerDetailViewState extends PollingRouteAwareState<ServerDetailView>
    with
        SingleTickerProviderStateMixin,
        DetailDirtySnackBarMixin<ServerDetailView> {
  static const int _tabStats = 1;

  late final TabController _tabController;
  final _outerScrollController = ScrollController();
  final _nestedScrollKey = GlobalKey<NestedScrollViewState>();
  Timer? _statsRefreshTimer;
  ProviderSubscription<AsyncValue<SystemStats?>>? _statsSubscription;
  final _configEditorKey = GlobalKey<ServerConfigEditorContentState>();
  var _configSaveInFlight = false;

  DateTime? _previousSampleTs;
  double? _previousIngressBytes;
  double? _previousEgressBytes;
  double? _ingressBytesPerSecond;
  double? _egressBytesPerSecond;
  final List<StatsSample> _history = <StatsSample>[];
  static const int _maxHistorySamples = 120; // ~5 minutes @ 2.5s

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onInnerTabChanged);

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
    _tabController
      ..removeListener(_onInnerTabChanged)
      ..dispose();
    _outerScrollController.dispose();
    super.dispose();
  }

  @override
  void onVisibilityChanged() {
    if (!mounted) return;
    _syncStatsTimer(isShellTabActive: ref.read(mainShellIndexProvider) == 1);
    super.onVisibilityChanged();
  }

  void _onInnerTabChanged() {
    if (!mounted) return;
    _syncStatsTimer(isShellTabActive: ref.read(mainShellIndexProvider) == 1);
  }

  void _startStatsTimer() {
    if (_statsRefreshTimer != null) return;
    _statsRefreshTimer = Timer.periodic(const Duration(milliseconds: 2500), (
      _,
    ) {
      ref.invalidate(serverStatsProvider(widget.serverId));
    });
    ref.invalidate(serverStatsProvider(widget.serverId));
  }

  void _stopStatsTimer() {
    _statsRefreshTimer?.cancel();
    _statsRefreshTimer = null;
  }

  void _syncStatsTimer({required bool isShellTabActive}) {
    final isStatsTabActive = _tabController.index == _tabStats;
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

      _history.add(
        StatsSample(
          ts: DateTime.now(),
          cpuPercent: stats.cpuPercent,
          memPercent: stats.memPercent,
          diskPercent: stats.diskPercent,
          ingressBytesPerSecond: ingressBps,
          egressBytesPerSecond: egressBps,
        ),
      );
      if (_history.length > _maxHistorySamples) {
        _history.removeRange(0, _history.length - _maxHistorySamples);
      }
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

    return Scaffold(
      appBar: MainAppBar(
        title: widget.serverName,
        icon: AppIcons.server,
        markColor: AppTokens.resourceServers,
        markUseGradient: true,
        centerTitle: true,
      ),
      body: NestedScrollView(
        key: _nestedScrollKey,
        controller: _outerScrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: ServerHeroPanel(
                  server: server ?? listServer,
                  listServer: listServer,
                  stats: stats,
                  systemInformation: systemInformation,
                  ingressBytesPerSecond: _ingressBytesPerSecond,
                  egressBytesPerSecond: _egressBytesPerSecond,
                ),
              ),
            ),
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                context,
              ),
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedTabBarHeaderDelegate(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  tabBar: buildDetailTabBar(
                    context: context,
                    controller: _tabController,
                    outerScrollController: _outerScrollController,
                    nestedScrollKey: _nestedScrollKey,
                    tabs: const [
                      Tab(
                        icon: Icon(AppIcons.bolt),
                        text: 'Config',
                      ),
                      Tab(
                        icon: Icon(AppIcons.activity),
                        text: 'Stats',
                      ),
                      Tab(
                        icon: Icon(AppIcons.cpu),
                        text: 'System',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _KeepAlive(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref
                    ..invalidate(serverDetailProvider(widget.serverId))
                    ..invalidate(
                      serverSystemInformationProvider(widget.serverId),
                    )
                    ..invalidate(serverStatsProvider(widget.serverId));
                },
                child: DetailTabScrollView.box(
                  scrollKey:
                      PageStorageKey('server_${widget.serverId}_config'),
                  child: serverAsync.when(
                    data: (server) => server?.config != null
                        ? ServerConfigEditorContent(
                            key: _configEditorKey,
                            initialConfig: server!.config!,
                            onDirtyChanged: (dirty) {
                              syncDirtySnackBar(
                                dirty: dirty,
                                onDiscard: () => _discardConfig(server),
                                onSave: () => _saveConfig(server: server),
                                saveEnabled: !_configSaveInFlight,
                              );
                            },
                          )
                        : const ServerMessageCard(
                            message: 'No config available',
                          ),
                    loading: () => const ServerLoadingCard(),
                    error: (error, _) =>
                        ServerMessageCard(message: 'Config: $error'),
                  ),
                ),
              ),
            ),
            _KeepAlive(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref
                    ..invalidate(serverDetailProvider(widget.serverId))
                    ..invalidate(
                      serverSystemInformationProvider(widget.serverId),
                    )
                    ..invalidate(serverStatsProvider(widget.serverId));
                },
                child: DetailTabScrollView.box(
                  scrollKey:
                      PageStorageKey('server_${widget.serverId}_stats'),
                  child: statsAsync.when(
                    data: (stats) => DetailSurface(
                      child: StatsHistoryContent(
                        history: _history,
                        latestStats: stats,
                      ),
                    ),
                    loading: () => const ServerLoadingCard(),
                    error: (error, _) => ServerMessageCard(
                      message: 'Stats unavailable: $error',
                    ),
                  ),
                ),
              ),
            ),
            _KeepAlive(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref
                    ..invalidate(serverDetailProvider(widget.serverId))
                    ..invalidate(
                      serverSystemInformationProvider(widget.serverId),
                    )
                    ..invalidate(serverStatsProvider(widget.serverId));
                },
                child: DetailTabScrollView.box(
                  scrollKey:
                      PageStorageKey('server_${widget.serverId}_system'),
                  child: systemInfoAsync.when(
                    data: (info) => info != null
                        ? DetailSurface(
                            child: ServerSystemInfoContent(info: info),
                          )
                        : const ServerMessageCard(
                            message: 'System info unavailable',
                          ),
                    loading: () => const ServerLoadingCard(),
                    error: (error, _) => ServerMessageCard(
                      message: 'System info unavailable: $error',
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

class _PinnedTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedTabBarHeaderDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  final PreferredSizeWidget tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Align(alignment: Alignment.centerLeft, child: tabBar),
    );
  }

  @override
  bool shouldRebuild(_PinnedTabBarHeaderDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar ||
      backgroundColor != oldDelegate.backgroundColor;
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin<_KeepAlive> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}
