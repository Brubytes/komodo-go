import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/home/home_ops_pulse.dart';
import 'package:komodo_go/composition/home/home_server_overview_provider.dart';
import 'package:komodo_go/composition/home/widgets/home_attention_card.dart';
import 'package:komodo_go/composition/home/widgets/home_dashboard_tiles.dart';
import 'package:komodo_go/composition/home/widgets/home_sections.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/status_colors.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:komodo_go/features/notifications/presentation/utils/alerts_error_utils.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/providers/resource_view_prefs_provider.dart';
import 'package:komodo_go/shared/resources/providers/resources_target_provider.dart';

void _goToResources(
  BuildContext context,
  WidgetRef ref,
  ResourceType resourceType, {
  bool problemsOnly = false,
}) {
  if (problemsOnly) {
    final kind = ResourceKind.values.byName(resourceType.name);
    ref.read(resourceProblemsOnlyProvider(kind.name).notifier).enabled = true;
  }
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

/// Home dashboard view.
///
/// The page itself watches nothing: every section is its own
/// [ConsumerWidget] and only rebuilds when the data it shows changes.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeAttentionCard(),
                  Gap(20),
                ],
              ),
            ),
            staggeredSection(const HomeServerOverviewSection()),
            staggeredSection(const HomeAlertsSection()),
            staggeredSection(const HomeOpsPulseSection()),
          ],
        ),
      ),
    );
  }
}

/// Metric grid + horizontal per-server stat tiles.
class HomeServerOverviewSection extends ConsumerWidget {
  const HomeServerOverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(title: 'Server overview'),
        const Gap(8),
        ref
            .watch(homeServerOverviewProvider)
            .when(
              data: (overview) {
                if (overview == null) {
                  return const HomeEmptyListTile(
                    icon: AppIcons.server,
                    message: 'No servers yet',
                  );
                }
                return Column(
                  children: [
                    _ServerMetricGrid(
                      overview: overview,
                      onServersTap: () =>
                          _goToResources(context, ref, ResourceType.servers),
                    ),
                    const Gap(16),
                    HomeSectionHeader(
                      title: 'Server stats',
                      onSeeAll: () =>
                          _goToResources(context, ref, ResourceType.servers),
                    ),
                    const Gap(8),
                    const _ServerStatTiles(),
                  ],
                );
              },
              loading: () => const HomeLoadingTile(),
              error: (e, _) => HomeErrorTile(message: e.toString()),
            ),
        const Gap(20),
      ],
    );
  }
}

class _ServerMetricGrid extends StatelessWidget {
  const _ServerMetricGrid({
    required this.overview,
    required this.onServersTap,
  });

  final HomeServerOverview overview;
  final VoidCallback onServersTap;

  static const double _spacing = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 720 ? 4 : (width >= 520 ? 3 : 2);
        final aspectRatio = switch (columns) {
          4 => 1.85,
          3 => 1.55,
          _ => 1.4,
        };
        final cellWidth = (width - _spacing * (columns - 1)) / columns;
        final cellHeight = cellWidth / aspectRatio;

        Widget cell(Widget child) =>
            SizedBox(width: cellWidth, height: cellHeight, child: child);

        // Fixed non-scrolling layout: no nested scrollable/shrink-wrap pass.
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            cell(
              HomeMetricCard(
                title: 'CPU Avg',
                value: overview.cpuValue,
                subtitle: overview.cpuSubtitle,
                icon: AppIcons.cpu,
              ),
            ),
            cell(
              HomeMetricCard(
                title: 'Memory Avg',
                value: overview.memValue,
                subtitle: overview.memSubtitle,
                icon: AppIcons.memory,
              ),
            ),
            cell(
              HomeMetricCard(
                title: 'Disk Avg',
                value: overview.diskValue,
                subtitle: overview.diskSubtitle,
                icon: AppIcons.hardDrive,
              ),
            ),
            cell(
              HomeMetricCard(
                title: 'Servers',
                value: overview.serverCount,
                subtitle: overview.serverSubtitle,
                icon: AppIcons.server,
                onTap: onServersTap,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ServerStatTiles extends ConsumerWidget {
  const _ServerStatTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider).asData?.value ?? const [];
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: servers.length,
        separatorBuilder: (_, _) => const Gap(8),
        itemBuilder: (context, index) {
          final server = servers[index];
          // Each tile watches only its own server's stats.
          return Consumer(
            key: ValueKey(server.id),
            builder: (context, ref, _) => HomeServerStatTile(
              server: server,
              stats: ref.watch(serverStatsProvider(server.id)),
            ),
          );
        },
      ),
    );
  }
}

@immutable
class _AlertsSummary {
  const _AlertsSummary({
    required this.unresolvedCount,
    required this.critical,
    required this.warning,
    required this.unknown,
    required this.preview,
  });

  factory _AlertsSummary.from(List<Alert> items) {
    final unresolved = items.where((alert) => !alert.resolved).toList();
    int count(SeverityLevel level) =>
        unresolved.where((alert) => alert.level == level).length;
    return _AlertsSummary(
      unresolvedCount: unresolved.length,
      critical: count(SeverityLevel.critical),
      warning: count(SeverityLevel.warning),
      unknown: count(SeverityLevel.unknown),
      preview: unresolved.take(3).toList(),
    );
  }

  final int unresolvedCount;
  final int critical;
  final int warning;
  final int unknown;
  final List<Alert> preview;

  @override
  bool operator ==(Object other) =>
      other is _AlertsSummary &&
      other.unresolvedCount == unresolvedCount &&
      other.critical == critical &&
      other.warning == warning &&
      other.unknown == unknown &&
      listEquals(other.preview, preview);

  @override
  int get hashCode =>
      Object.hash(unresolvedCount, critical, warning, unknown, preview.length);
}

/// Unresolved-alert summary; rebuilds only when the summary itself changes.
class HomeAlertsSection extends ConsumerWidget {
  const HomeAlertsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(
      alertsProvider.select(
        (value) => value.whenData((state) => _AlertsSummary.from(state.items)),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Alerts',
          onSeeAll: () => context.go(AppRoutes.notifications),
        ),
        const Gap(8),
        alertsAsync.when(
          data: (summary) {
            if (summary.unresolvedCount == 0) {
              return const HomeEmptyListTile(
                icon: AppIcons.warning,
                message: 'No unresolved alerts',
              );
            }
            final summaryParts = <String>[
              if (summary.critical > 0) '${summary.critical} critical',
              if (summary.warning > 0) '${summary.warning} warning',
              if (summary.unknown > 0) '${summary.unknown} unknown',
            ];
            final summaryText = summaryParts.isEmpty
                ? 'No severity data'
                : summaryParts.join(' · ');
            final scheme = Theme.of(context).colorScheme;
            final summaryColor = summary.critical > 0
                ? scheme.error
                : summary.warning > 0
                ? scheme.statusWarning
                : scheme.onSurfaceVariant;

            return Column(
              children: [
                HomeAlertSummaryCard(
                  count: summary.unresolvedCount,
                  summary: summaryText,
                  color: summaryColor,
                  onTap: () => context.go(AppRoutes.notifications),
                ),
                const Gap(8),
                for (final alert in summary.preview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: HomeAlertPreviewTile(alert: alert),
                  ),
              ],
            );
          },
          loading: () => const HomeLoadingTile(),
          error: (e, _) {
            if (isAlertsPermissionError(e)) {
              return const HomeEmptyListTile(
                icon: AppIcons.notifications,
                message:
                    'Alerts unavailable for this account. Check Updates instead.',
              );
            }
            return HomeErrorTile(message: e.toString());
          },
        ),
        const Gap(20),
      ],
    );
  }
}

/// Operational resource overview across all resource kinds.
class HomeOpsPulseSection extends ConsumerWidget {
  const HomeOpsPulseSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(title: 'Ops pulse'),
        const Gap(8),
        _buildOpsPulseCard(
          context: context,
          deploymentsAsync: ref.watch(deploymentsProvider),
          stacksAsync: ref.watch(stacksProvider),
          reposAsync: ref.watch(reposProvider),
          syncsAsync: ref.watch(syncsProvider),
          buildsAsync: ref.watch(buildsProvider),
          proceduresAsync: ref.watch(proceduresProvider),
          actionsAsync: ref.watch(actionsProvider),
          onNavigate: (row) => _goToResources(
            context,
            ref,
            row.type,
            problemsOnly: row.statuses.any(
              (s) => s.tone == HomeOpsTone.failed && s.count > 0,
            ),
          ),
        ),
        const Gap(20),
      ],
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
  required void Function(HomeOpsRowData row) onNavigate,
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

  final snapshot = buildHomeOpsSnapshot(
    deployments: deployments,
    stacks: stacks,
    builds: builds,
    repos: repos,
    procedures: procedures,
    actions: actions,
    syncs: syncs,
  );
  if (snapshot.totalResources == 0) {
    return const HomeEmptyListTile(
      icon: AppIcons.activity,
      message: 'No operational resources yet',
    );
  }

  final summary = <HomeOpsStatusCount>[
    HomeOpsStatusCount(
      label: 'healthy',
      count: snapshot.count(HomeOpsTone.healthy),
      tone: HomeOpsTone.healthy,
    ),
    HomeOpsStatusCount(
      label: 'in progress',
      count: snapshot.count(HomeOpsTone.active),
      tone: HomeOpsTone.active,
    ),
    HomeOpsStatusCount(
      label: 'attention',
      count: snapshot.count(HomeOpsTone.attention),
      tone: HomeOpsTone.attention,
    ),
    HomeOpsStatusCount(
      label: 'failed',
      count: snapshot.count(HomeOpsTone.failed),
      tone: HomeOpsTone.failed,
    ),
    HomeOpsStatusCount(
      label: 'unknown',
      count: snapshot.count(HomeOpsTone.unknown),
      tone: HomeOpsTone.unknown,
    ),
  ];

  return AppCardSurface(
    padding: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final status in summary)
                if (status.count > 0)
                  _OpsSummaryChip(
                    label: '${status.count} ${status.label}',
                    color: _opsToneColor(context, status.tone),
                  ),
            ],
          ),
          const Gap(12),
          ...snapshot.rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: HomeOpsStatusRow(
                title: row.title,
                statuses: row.statuses,
                onTap: () => onNavigate(row),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Color _opsToneColor(BuildContext context, HomeOpsTone tone) {
  final scheme = Theme.of(context).colorScheme;
  return switch (tone) {
    HomeOpsTone.healthy => scheme.statusSuccess,
    HomeOpsTone.active => scheme.primary,
    HomeOpsTone.attention => scheme.statusWarning,
    HomeOpsTone.failed => scheme.error,
    HomeOpsTone.unknown => scheme.onSurfaceVariant,
  };
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
