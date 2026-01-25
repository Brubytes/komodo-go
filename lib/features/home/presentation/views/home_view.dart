import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/home/presentation/views/home/home_dashboard_tiles.dart';
import 'package:komodo_go/features/home/presentation/views/home/home_sections.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/resources/presentation/providers/resources_tab_provider.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';

/// Home dashboard view.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  void _goToResources(BuildContext context, ResourceType resourceType) {
    final route = switch (resourceType) {
      ResourceType.servers => AppRoutes.servers,
      ResourceType.deployments => AppRoutes.deployments,
      ResourceType.stacks => AppRoutes.stacks,
      ResourceType.repos => AppRoutes.repos,
      ResourceType.syncs => AppRoutes.syncs,
      ResourceType.builds => AppRoutes.builds,
      ResourceType.procedures => AppRoutes.procedures,
      ResourceType.actions => AppRoutes.actions,
    };
    context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final overviewColumns = width >= 720 ? 4 : (width >= 520 ? 3 : 2);
    final overviewAspectRatio = switch (overviewColumns) {
      4 => 1.85,
      3 => 1.55,
      _ => 1.4,
    };

    final serversAsync = ref.watch(serversProvider);
    final deploymentsAsync = ref.watch(deploymentsProvider);
    final stacksAsync = ref.watch(stacksProvider);
    final reposAsync = ref.watch(reposProvider);
    final syncsAsync = ref.watch(syncsProvider);
    final buildsAsync = ref.watch(buildsProvider);
    final proceduresAsync = ref.watch(proceduresProvider);
    final actionsAsync = ref.watch(actionsProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final updatesAsync = ref.watch(updatesProvider);
    var sectionIndex = 0;

    Widget staggeredSection(Widget child) {
      final delay = AppMotion.stagger(sectionIndex++);
      return AppFadeSlide(delay: delay, child: child);
    }

    return Scaffold(
      appBar: const MainAppBar(title: 'Dashboard', icon: AppIcons.home),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(serversProvider)
            ..invalidate(serverStatsProvider)
            ..invalidate(deploymentsProvider)
            ..invalidate(stacksProvider)
            ..invalidate(reposProvider)
            ..invalidate(syncsProvider)
            ..invalidate(buildsProvider)
            ..invalidate(proceduresProvider)
            ..invalidate(actionsProvider)
            ..invalidate(alertsProvider)
            ..invalidate(updatesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            staggeredSection(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HomeSectionHeader(title: 'Server overview'),
                  const Gap(8),
                  serversAsync.when(
                    data: (servers) {
                      if (servers.isEmpty) {
                        return const HomeEmptyListTile(
                          icon: AppIcons.server,
                          message: 'No servers yet',
                        );
                      }

                      final statsValues = [
                        for (final server in servers)
                          ref.watch(serverStatsProvider(server.id)),
                      ];
                      final statsEntries = <_ServerStatsEntry>[
                        for (var i = 0; i < servers.length; i++)
                          if (statsValues[i].asData?.value != null)
                            _ServerStatsEntry(
                              server: servers[i],
                              stats: statsValues[i].asData!.value!,
                            ),
                      ];
                      final summary = _ServerStatsSummary.from(
                        servers,
                        statsEntries,
                      );
                      final hasStats = summary.statsCount > 0;
                      final isStatsLoading = statsValues.any(
                        (value) => value.isLoading,
                      );

                      String avgWithTotals(double average, String totals) {
                        final avgLabel = '${average.toStringAsFixed(0)}%';
                        if (totals.isEmpty) return avgLabel;
                        return '$avgLabel\n$totals';
                      }

                      final cpuValue = hasStats
                          ? '${summary.avgCpu.toStringAsFixed(0)}%'
                          : '—';
                      final memValue = hasStats
                          ? avgWithTotals(
                              summary.avgMem,
                              summary.memTotalsLabel,
                            )
                          : '—';
                      final diskValue = hasStats
                          ? avgWithTotals(
                              summary.avgDisk,
                              summary.diskTotalsLabel,
                            )
                          : '—';

                      String statsSubtitle({
                        required double maxValue,
                        required String? serverName,
                      }) {
                        if (!hasStats) {
                          return isStatsLoading
                              ? 'Loading stats'
                              : 'No stats yet';
                        }
                        final label = 'max ${maxValue.toStringAsFixed(0)}%';
                        final name = (serverName?.trim().isNotEmpty ?? false)
                            ? serverName!.trim()
                            : null;
                        final parts = <String>[label, if (name != null) name];
                        return parts.join(' · ');
                      }

                      final serverSubtitleParts = <String>[];
                      if (summary.online > 0) {
                        serverSubtitleParts.add('${summary.online} online');
                      }
                      if (summary.offline > 0) {
                        serverSubtitleParts.add('${summary.offline} down');
                      }
                      if (summary.disabled > 0) {
                        serverSubtitleParts.add('${summary.disabled} disabled');
                      }
                      if (summary.unknown > 0) {
                        serverSubtitleParts.add('${summary.unknown} unknown');
                      }
                      final serverSubtitle = serverSubtitleParts.isEmpty
                          ? 'No status data'
                          : serverSubtitleParts.join(' · ');

                      return Column(
                        children: [
                          GridView.count(
                            crossAxisCount: overviewColumns,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: overviewAspectRatio,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              HomeMetricCard(
                                title: 'CPU Avg',
                                value: cpuValue,
                                subtitle: statsSubtitle(
                                  maxValue: summary.maxCpu,
                                  serverName: summary.maxCpuServerName,
                                ),
                                icon: AppIcons.cpu,
                              ),
                              HomeMetricCard(
                                title: 'Memory Avg',
                                value: memValue,
                                subtitle: statsSubtitle(
                                  maxValue: summary.maxMem,
                                  serverName: summary.maxMemServerName,
                                ),
                                icon: AppIcons.memory,
                              ),
                              HomeMetricCard(
                                title: 'Disk Avg',
                                value: diskValue,
                                subtitle: statsSubtitle(
                                  maxValue: summary.maxDisk,
                                  serverName: summary.maxDiskServerName,
                                ),
                                icon: AppIcons.hardDrive,
                              ),
                              HomeMetricCard(
                                title: 'Servers',
                                value: summary.total.toString(),
                                subtitle: serverSubtitle,
                                icon: AppIcons.server,
                                onTap: () => _goToResources(
                                  context,
                                  ResourceType.servers,
                                ),
                              ),
                            ],
                          ),
                          const Gap(16),
                          HomeSectionHeader(
                            title: 'Server stats',
                            onSeeAll: () =>
                                _goToResources(context, ResourceType.servers),
                          ),
                          const Gap(8),
                          SizedBox(
                            height: 130,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: servers.length,
                              separatorBuilder: (_, __) => const Gap(8),
                              itemBuilder: (context, index) {
                                return HomeServerStatTile(
                                  server: servers[index],
                                  stats: statsValues[index],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const HomeLoadingTile(),
                    error: (e, _) => HomeErrorTile(message: e.toString()),
                  ),
                  const Gap(20),
                ],
              ),
            ),
            staggeredSection(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeSectionHeader(
                    title: 'Alerts',
                    onSeeAll: () => context.go(AppRoutes.notifications),
                  ),
                  const Gap(8),
                  alertsAsync.when(
                    data: (state) {
                      final unresolved = state.items
                          .where((alert) => !alert.resolved)
                          .toList();
                      if (unresolved.isEmpty) {
                        return const HomeEmptyListTile(
                          icon: AppIcons.warning,
                          message: 'No unresolved alerts',
                        );
                      }

                      final criticalCount = unresolved
                          .where(
                            (alert) => alert.level == SeverityLevel.critical,
                          )
                          .length;
                      final warningCount = unresolved
                          .where(
                            (alert) => alert.level == SeverityLevel.warning,
                          )
                          .length;
                      final unknownCount = unresolved
                          .where(
                            (alert) => alert.level == SeverityLevel.unknown,
                          )
                          .length;
                      final summaryParts = <String>[];
                      if (criticalCount > 0) {
                        summaryParts.add('$criticalCount critical');
                      }
                      if (warningCount > 0) {
                        summaryParts.add('$warningCount warning');
                      }
                      if (unknownCount > 0) {
                        summaryParts.add('$unknownCount unknown');
                      }
                      final summaryText = summaryParts.isEmpty
                          ? 'No severity data'
                          : summaryParts.join(' · ');

                      return Column(
                        children: [
                          HomeMetricCard(
                            title: 'Unresolved alerts',
                            value: unresolved.length.toString(),
                            subtitle: summaryText,
                            icon: AppIcons.warning,
                            onTap: () => context.go(AppRoutes.notifications),
                          ),
                          const Gap(8),
                          ...unresolved
                              .take(3)
                              .map(
                                (alert) =>
                                    HomeAlertPreviewTile(alert: alert),
                              ),
                        ],
                      );
                    },
                    loading: () => const HomeLoadingTile(),
                    error: (e, _) => HomeErrorTile(message: e.toString()),
                  ),
                  const Gap(20),
                ],
              ),
            ),
            staggeredSection(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeSectionHeader(
                    title: 'Ops pulse',
                    onSeeAll: () =>
                        _goToResources(context, ResourceType.deployments),
                  ),
                  const Gap(8),
                  _buildOpsPulseCard(
                    context: context,
                    deploymentsAsync: deploymentsAsync,
                    stacksAsync: stacksAsync,
                    reposAsync: reposAsync,
                    syncsAsync: syncsAsync,
                    buildsAsync: buildsAsync,
                    proceduresAsync: proceduresAsync,
                    actionsAsync: actionsAsync,
                    onNavigate: (type) => _goToResources(context, type),
                  ),
                  const Gap(20),
                ],
              ),
            ),
            staggeredSection(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeSectionHeader(
                    title: 'Recent updates',
                    onSeeAll: () => context.go(AppRoutes.notifications),
                  ),
                  const Gap(8),
                  updatesAsync.when(
                    data: (state) {
                      if (state.items.isEmpty) {
                        return const HomeEmptyListTile(
                          icon: AppIcons.updateAvailable,
                          message: 'No recent updates',
                        );
                      }

                      return Column(
                        children: state.items
                            .take(3)
                            .map(
                              (update) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child:
                                    HomeUpdatePreviewTile(update: update),
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () => const HomeLoadingTile(),
                    error: (e, _) => HomeErrorTile(message: e.toString()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildOpsPulseCard({
  required BuildContext context,
  required AsyncValue<List<Deployment>> deploymentsAsync,
  required AsyncValue<List<StackListItem>> stacksAsync,
  required AsyncValue<List<RepoListItem>> reposAsync,
  required AsyncValue<List<ResourceSyncListItem>> syncsAsync,
  required AsyncValue<List<BuildListItem>> buildsAsync,
  required AsyncValue<List<ProcedureListItem>> proceduresAsync,
  required AsyncValue<List<ActionListItem>> actionsAsync,
  required void Function(ResourceType type) onNavigate,
}) {
  final asyncValues = <AsyncValue<dynamic>>[
    deploymentsAsync,
    stacksAsync,
    reposAsync,
    syncsAsync,
    buildsAsync,
    proceduresAsync,
    actionsAsync,
  ];

  final errorValue = asyncValues.cast<AsyncValue<dynamic>>().firstWhere(
    (value) => value.hasError,
    orElse: () => const AsyncValue.data(null),
  );

  final hasAnyValue = asyncValues.any((value) => value.hasValue);
  final isLoading = asyncValues.any((value) => value.isLoading);

  if (!hasAnyValue && isLoading) {
    return const HomeLoadingTile();
  }
  if (errorValue.hasError) {
    return HomeErrorTile(message: errorValue.error.toString());
  }

  final deployments = deploymentsAsync.asData?.value ?? <Deployment>[];
  final stacks = stacksAsync.asData?.value ?? <StackListItem>[];
  final repos = reposAsync.asData?.value ?? <RepoListItem>[];
  final syncs = syncsAsync.asData?.value ?? <ResourceSyncListItem>[];
  final builds = buildsAsync.asData?.value ?? <BuildListItem>[];
  final procedures = proceduresAsync.asData?.value ?? <ProcedureListItem>[];
  final actions = actionsAsync.asData?.value ?? <ActionListItem>[];

  final rows = <_OpsRowData>[
    _OpsRowData(
      title: 'Deployments',
      active: deployments
          .where(
            (item) =>
                item.info?.state == DeploymentState.deploying ||
                item.info?.state == DeploymentState.restarting ||
                item.info?.state == DeploymentState.removing,
          )
          .length,
      failed: deployments
          .where(
            (item) =>
                item.info?.state == DeploymentState.dead ||
                item.info?.state == DeploymentState.exited,
          )
          .length,
      type: ResourceType.deployments,
    ),
    _OpsRowData(
      title: 'Stacks',
      active: stacks
          .where(
            (item) =>
                item.info.state == StackState.deploying ||
                item.info.state == StackState.restarting,
          )
          .length,
      failed: stacks
          .where(
            (item) =>
                item.info.state == StackState.unhealthy ||
                item.info.state == StackState.dead,
          )
          .length,
      type: ResourceType.stacks,
    ),
    _OpsRowData(
      title: 'Builds',
      active: builds
          .where((item) => item.info.state == BuildState.building)
          .length,
      failed: builds
          .where((item) => item.info.state == BuildState.failed)
          .length,
      type: ResourceType.builds,
    ),
    _OpsRowData(
      title: 'Procedures',
      active: procedures
          .where((item) => item.info.state == ProcedureState.running)
          .length,
      failed: procedures
          .where((item) => item.info.state == ProcedureState.failed)
          .length,
      type: ResourceType.procedures,
    ),
    _OpsRowData(
      title: 'Actions',
      active: actions
          .where((item) => item.info.state == ActionState.running)
          .length,
      failed: actions
          .where((item) => item.info.state == ActionState.failed)
          .length,
      type: ResourceType.actions,
    ),
    _OpsRowData(
      title: 'Syncs',
      active: syncs.where((item) => item.info.state.isRunning).length,
      failed: syncs
          .where((item) => item.info.state == ResourceSyncState.failed)
          .length,
      type: ResourceType.syncs,
    ),
    _OpsRowData(
      title: 'Repos',
      active: repos.where((item) => item.info.state.isBusy).length,
      failed: repos.where((item) => item.info.state == RepoState.failed).length,
      type: ResourceType.repos,
    ),
  ];

  final totalActive = rows.fold<int>(0, (sum, row) => sum + row.active);
  final totalFailed = rows.fold<int>(0, (sum, row) => sum + row.failed);

  return AppCardSurface(
    padding: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _OpsSummaryChip(
                label: '$totalActive active',
                color: Theme.of(context).colorScheme.primary,
              ),
              const Gap(8),
              _OpsSummaryChip(
                label: '$totalFailed failed',
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ),
          const Gap(12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: HomeOpsStatusRow(
                title: row.title,
                active: row.active,
                failed: row.failed,
                onTap: () => onNavigate(row.type),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OpsSummaryChip extends StatelessWidget {
  const _OpsSummaryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OpsRowData {
  const _OpsRowData({
    required this.title,
    required this.active,
    required this.failed,
    required this.type,
  });

  final String title;
  final int active;
  final int failed;
  final ResourceType type;
}

class _ServerStatsEntry {
  const _ServerStatsEntry({required this.server, required this.stats});

  final Server server;
  final SystemStats stats;
}

class _ServerStatsSummary {
  const _ServerStatsSummary({
    required this.total,
    required this.online,
    required this.offline,
    required this.disabled,
    required this.unknown,
    required this.avgCpu,
    required this.avgMem,
    required this.avgDisk,
    required this.maxCpu,
    required this.maxMem,
    required this.maxDisk,
    required this.maxCpuServerName,
    required this.maxMemServerName,
    required this.maxDiskServerName,
    required this.totalMemUsedGb,
    required this.totalMemGb,
    required this.totalDiskUsedGb,
    required this.totalDiskGb,
    required this.statsCount,
  });

  factory _ServerStatsSummary.from(
    List<Server> servers,
    List<_ServerStatsEntry> entries,
  ) {
    final total = servers.length;
    final online = servers
        .where((server) => server.state == ServerState.ok)
        .length;
    final offline = servers
        .where((server) => server.state == ServerState.notOk)
        .length;
    final disabled = servers
        .where((server) => server.state == ServerState.disabled)
        .length;
    final unknown = servers
        .where((server) => server.state == ServerState.unknown)
        .length;

    if (entries.isEmpty) {
      return _ServerStatsSummary(
        total: total,
        online: online,
        offline: offline,
        disabled: disabled,
        unknown: unknown,
        avgCpu: 0,
        avgMem: 0,
        avgDisk: 0,
        maxCpu: 0,
        maxMem: 0,
        maxDisk: 0,
        maxCpuServerName: null,
        maxMemServerName: null,
        maxDiskServerName: null,
        totalMemUsedGb: 0,
        totalMemGb: 0,
        totalDiskUsedGb: 0,
        totalDiskGb: 0,
        statsCount: 0,
      );
    }

    var sumCpu = 0.0;
    var sumMem = 0.0;
    var sumDisk = 0.0;
    var totalMemUsed = 0.0;
    var totalMem = 0.0;
    var totalDiskUsed = 0.0;
    var totalDisk = 0.0;

    var maxCpu = -1.0;
    var maxMem = -1.0;
    var maxDisk = -1.0;
    String? maxCpuServerName;
    String? maxMemServerName;
    String? maxDiskServerName;

    for (final entry in entries) {
      final stats = entry.stats;
      sumCpu += stats.cpuPercent;
      sumMem += stats.memPercent;
      sumDisk += stats.diskPercent;

      totalMemUsed += stats.memUsedGb;
      totalMem += stats.memTotalGb;
      totalDiskUsed += stats.diskUsedGb;
      totalDisk += stats.diskTotalGb;

      if (stats.cpuPercent >= maxCpu) {
        maxCpu = stats.cpuPercent;
        maxCpuServerName = entry.server.name;
      }
      if (stats.memPercent >= maxMem) {
        maxMem = stats.memPercent;
        maxMemServerName = entry.server.name;
      }
      if (stats.diskPercent >= maxDisk) {
        maxDisk = stats.diskPercent;
        maxDiskServerName = entry.server.name;
      }
    }

    final count = entries.length.toDouble();

    return _ServerStatsSummary(
      total: total,
      online: online,
      offline: offline,
      disabled: disabled,
      unknown: unknown,
      avgCpu: sumCpu / count,
      avgMem: sumMem / count,
      avgDisk: sumDisk / count,
      maxCpu: maxCpu < 0 ? 0 : maxCpu,
      maxMem: maxMem < 0 ? 0 : maxMem,
      maxDisk: maxDisk < 0 ? 0 : maxDisk,
      maxCpuServerName: maxCpuServerName,
      maxMemServerName: maxMemServerName,
      maxDiskServerName: maxDiskServerName,
      totalMemUsedGb: totalMemUsed,
      totalMemGb: totalMem,
      totalDiskUsedGb: totalDiskUsed,
      totalDiskGb: totalDisk,
      statsCount: entries.length,
    );
  }

  final int total;
  final int online;
  final int offline;
  final int disabled;
  final int unknown;
  final double avgCpu;
  final double avgMem;
  final double avgDisk;
  final double maxCpu;
  final double maxMem;
  final double maxDisk;
  final String? maxCpuServerName;
  final String? maxMemServerName;
  final String? maxDiskServerName;
  final double totalMemUsedGb;
  final double totalMemGb;
  final double totalDiskUsedGb;
  final double totalDiskGb;
  final int statsCount;

  String get memTotalsLabel => _totalsLabel(totalMemUsedGb, totalMemGb);
  String get diskTotalsLabel => _totalsLabel(totalDiskUsedGb, totalDiskGb);

  String _totalsLabel(double used, double total) {
    if (total <= 0) return '';
    return _formatCapacity(used, total);
  }

  String _formatCapacity(double usedGb, double totalGb) {
    if (totalGb >= 1024) {
      final usedTb = usedGb / 1024;
      final totalTb = totalGb / 1024;
      return '${_formatNumber(usedTb)}/${_formatNumber(totalTb)}TB';
    }
    return '${_formatNumber(usedGb, decimals: 0)}/${_formatNumber(totalGb, decimals: 0)}GB';
  }

  String _formatNumber(double value, {int decimals = 1}) {
    final fixed = value.toStringAsFixed(decimals);
    if (decimals == 0) return fixed;
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }
}
