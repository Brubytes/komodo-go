import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/repos/presentation/widgets/repo_card.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';

/// View displaying detailed repo information.
class RepoDetailView extends ConsumerWidget {
  const RepoDetailView({
    required this.repoId,
    required this.repoName,
    super.key,
  });

  final String repoId;
  final String repoName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(repoDetailProvider(repoId));
    final actionsState = ref.watch(repoActionsProvider);
    final serversListAsync = ref.watch(serversProvider);

    final scheme = Theme.of(context).colorScheme;

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
        title: repoName,
        icon: AppIcons.repos,
        markColor: Colors.orange,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          PopupMenuButton<RepoAction>(
            icon: const Icon(AppIcons.moreVertical),
            onSelected: (action) => _handleAction(context, ref, repoId, action),
            itemBuilder: (context) => [
              komodoPopupMenuItem(
                value: RepoAction.clone,
                icon: AppIcons.download,
                label: 'Clone',
                iconColor: scheme.primary,
              ),
              komodoPopupMenuItem(
                value: RepoAction.pull,
                icon: AppIcons.refresh,
                label: 'Pull',
                iconColor: scheme.secondary,
              ),
              komodoPopupMenuItem(
                value: RepoAction.build,
                icon: AppIcons.builds,
                label: 'Build',
                iconColor: scheme.tertiary,
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(repoDetailProvider(repoId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                repoAsync.when(
                  data: (repo) => repo != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RepoHeroPanel(
                              repo: repo,
                              serverName: serverNameForId(repo.config.serverId),
                            ),
                            const Gap(16),
                            DetailSection(
                              title: 'Config',
                              icon: AppIcons.settings,
                              child: _RepoConfigContent(
                                config: repo.config,
                                serverName: serverNameForId(
                                  repo.config.serverId,
                                ),
                              ),
                            ),
                            const Gap(16),
                            DetailSection(
                              title: 'Build Status',
                              icon: AppIcons.builds,
                              child: _RepoBuildContent(info: repo.info),
                            ),
                          ],
                        )
                      : const _MessageSurface(message: 'Repo not found'),
                  loading: () => const _LoadingSurface(),
                  error: (error, _) =>
                      _MessageSurface(message: 'Error: $error'),
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
    WidgetRef ref,
    String repoId,
    RepoAction action,
  ) async {
    final actions = ref.read(repoActionsProvider.notifier);
    final success = await switch (action) {
      RepoAction.clone => actions.clone(repoId),
      RepoAction.pull => actions.pull(repoId),
      RepoAction.build => actions.buildRepo(repoId),
    };

    if (success) {
      ref.invalidate(repoDetailProvider(repoId));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Action completed successfully'
                : 'Action failed. Please try again.',
          ),
          backgroundColor: success
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }
}

class _RepoHeroPanel extends StatelessWidget {
  const _RepoHeroPanel({required this.repo, required this.serverName});

  final KomodoRepo repo;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final config = repo.config;
    final info = repo.info;

    final latest = info.latestHash;
    final built = info.builtHash;
    final upToDate = latest != null && built == latest;

    return DetailHeroPanel(
      tintColor: scheme.primary,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (repo.description.trim().isNotEmpty) ...[
            DetailIconInfoRow(
              icon: AppIcons.tag,
              label: 'Description',
              value: repo.description.trim(),
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
          if (config.serverId.isNotEmpty)
            DetailIconInfoRow(
              icon: AppIcons.server,
              label: 'Server',
              value: serverName ?? config.serverId,
            ),
        ],
      ),
      metrics: [
        DetailMetricTileData(
          icon: _stateIcon(RepoState.unknown),
          label: 'Status',
          value: '—',
          tone: DetailMetricTone.neutral,
        ),
        DetailMetricTileData(
          icon: AppIcons.repos,
          label: 'Branch',
          value: config.branch.isNotEmpty ? config.branch : '—',
          tone: DetailMetricTone.neutral,
        ),
        DetailMetricTileData(
          icon: config.webhookEnabled ? AppIcons.ok : AppIcons.pause,
          label: 'Webhook',
          value: config.webhookEnabled ? 'Enabled' : 'Disabled',
          tone: config.webhookEnabled
              ? DetailMetricTone.success
              : DetailMetricTone.neutral,
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
        children: [for (final tag in repo.tags) TextPill(label: tag)],
      ),
    );
  }

  IconData _stateIcon(RepoState state) {
    return switch (state) {
      RepoState.ok => AppIcons.ok,
      RepoState.cloning ||
      RepoState.pulling ||
      RepoState.building => AppIcons.loading,
      RepoState.failed => AppIcons.error,
      _ => AppIcons.unknown,
    };
  }
}

class _RepoConfigContent extends StatelessWidget {
  const _RepoConfigContent({required this.config, required this.serverName});

  final RepoConfig config;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill.onOff(
              isOn: config.webhookEnabled,
              onLabel: 'Webhook on',
              offLabel: 'Webhook off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.gitHttps,
              onLabel: 'HTTPS',
              offLabel: 'SSH',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
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
                label: 'Provider',
                value: config.gitProvider.isNotEmpty ? config.gitProvider : '—',
              ),
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
              ),
              DetailKeyValueRow(
                label: 'Account',
                value: config.gitAccount.isNotEmpty ? config.gitAccount : '—',
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
                label: 'Path',
                value: config.path.isNotEmpty ? config.path : '—',
                bottomPadding: 0,
              ),
            ],
          ),
        ),
        if (config.serverId.isNotEmpty || config.builderId.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Deployment',
            icon: AppIcons.server,
            child: Column(
              children: [
                if (config.serverId.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Server',
                    value: serverName ?? config.serverId,
                  ),
                if (config.builderId.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Builder',
                    value: config.builderId,
                    bottomPadding: 0,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RepoBuildContent extends StatelessWidget {
  const _RepoBuildContent({required this.info});

  final RepoInfo info;

  @override
  Widget build(BuildContext context) {
    final latest = info.latestHash;
    final built = info.builtHash;
    final upToDate = latest != null && built == latest;

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
                label: 'Built',
                value: _shortHash(built) ?? '—',
              ),
              if (info.builtMessage?.trim().isNotEmpty ?? false)
                DetailKeyValueRow(
                  label: 'Message',
                  value: info.builtMessage!.trim(),
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
        if (info.lastPulledAt > 0 || info.lastBuiltAt > 0) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Timestamps',
            icon: AppIcons.activity,
            child: Column(
              children: [
                if (info.lastPulledAt > 0)
                  DetailKeyValueRow(
                    label: 'Last pulled',
                    value: _formatTimestamp(info.lastPulledAt),
                  ),
                if (info.lastBuiltAt > 0)
                  DetailKeyValueRow(
                    label: 'Last built',
                    value: _formatTimestamp(info.lastBuiltAt),
                    bottomPadding: 0,
                  ),
              ],
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

  String _formatTimestamp(int ms) {
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
