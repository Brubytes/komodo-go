import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/polling_route_aware_state.dart';
import 'package:komodo_go/core/router/shell_state_provider.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
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

class _ServerDetailViewState
    extends PollingRouteAwareState<ServerDetailView> {
  Timer? _statsRefreshTimer;
  ProviderSubscription<AsyncValue<SystemStats?>>? _statsSubscription;

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
    _syncStatsTimer(isActiveTab: ref.read(mainShellIndexProvider) == 1);
    super.onVisibilityChanged();
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

  void _syncStatsTimer({required bool isActiveTab}) {
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
      _syncStatsTimer(isActiveTab: isActiveTab);
    });

    final serverAsync = ref.watch(serverDetailProvider(widget.serverId));
    final statsAsync = ref.watch(serverStatsProvider(widget.serverId));
    final systemInfoAsync = ref.watch(
      serverSystemInformationProvider(widget.serverId),
    );
    final serversListAsync = ref.watch(serversProvider);

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
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(serverDetailProvider(widget.serverId))
            ..invalidate(serverSystemInformationProvider(widget.serverId))
            ..invalidate(serverStatsProvider(widget.serverId));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            ServerHeroPanel(
              server: server ?? listServer,
              listServer: listServer,
              stats: stats,
              systemInformation: systemInformation,
              ingressBytesPerSecond: _ingressBytesPerSecond,
              egressBytesPerSecond: _egressBytesPerSecond,
            ),
            const Gap(16),
            statsAsync.when(
              data: (stats) => DetailSection(
                title: 'Stats',
                icon: AppIcons.activity,
                child: StatsHistoryContent(
                  history: _history,
                  latestStats: stats,
                ),
              ),
              loading: () => const ServerLoadingCard(),
              error: (error, _) =>
                  ServerMessageCard(message: 'Stats unavailable: $error'),
            ),
            const Gap(16),
            serverAsync.when(
              data: (server) => server?.config != null
                  ? DetailSection(
                      title: 'Config',
                      icon: AppIcons.settings,
                      child: ServerConfigContent(config: server!.config!),
                    )
                  : const ServerMessageCard(message: 'No config available'),
              loading: () => const ServerLoadingCard(),
              error: (error, _) => ServerMessageCard(message: 'Config: $error'),
            ),
            const Gap(16),
            systemInfoAsync.when(
              data: (info) => info != null
                  ? DetailSection(
                      title: 'System',
                      icon: AppIcons.server,
                      child: ServerSystemInfoContent(info: info),
                    )
                  : const ServerMessageCard(message: 'System info unavailable'),
              loading: () => const ServerLoadingCard(),
              error: (error, _) =>
                  ServerMessageCard(message: 'System info unavailable: $error'),
            ),
          ],
        ),
      ),
    );
  }
}
