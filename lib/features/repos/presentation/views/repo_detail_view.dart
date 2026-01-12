import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';
import 'package:komodo_go/features/providers/data/models/git_provider_account.dart';
import 'package:komodo_go/features/providers/presentation/providers/git_providers_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/repos/presentation/views/repo_detail/repo_detail_sections.dart';
import 'package:komodo_go/features/repos/presentation/widgets/repo_card.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';

/// View displaying detailed repo information.
class RepoDetailView extends ConsumerStatefulWidget {
  const RepoDetailView({
    required this.repoId,
    required this.repoName,
    super.key,
  });

  final String repoId;
  final String repoName;

  @override
  ConsumerState<RepoDetailView> createState() => _RepoDetailViewState();
}

class _RepoDetailViewState extends ConsumerState<RepoDetailView>
    with DetailDirtySnackBarMixin<RepoDetailView> {
  final _configEditorKey = GlobalKey<RepoConfigEditorContentState>();

  var _configSaveInFlight = false;

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(repoDetailProvider(widget.repoId));
    final actionsState = ref.watch(repoActionsProvider);
    final serversListAsync = ref.watch(serversProvider);
    final buildersListAsync = ref.watch(buildersProvider);
    final gitProvidersAsync = ref.watch(gitProvidersProvider);

    final scheme = Theme.of(context).colorScheme;

    String? serverNameForId(String serverId) {
      final servers = serversListAsync.asData?.value;
      if (servers == null || serverId.isEmpty) return null;
      for (final s in servers) {
        if (s.id == serverId) return s.name;
      }
      return null;
    }

    final servers = serversListAsync.asData?.value ?? const <Server>[];
    final builders =
        buildersListAsync.asData?.value ?? const <BuilderListItem>[];
    final gitProviders =
        gitProvidersAsync.asData?.value ?? const <GitProviderAccount>[];

    return Scaffold(
      appBar: MainAppBar(
        title: widget.repoName,
        icon: AppIcons.repos,
        markColor: AppTokens.resourceRepos,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          PopupMenuButton<RepoAction>(
            icon: const Icon(AppIcons.moreVertical),
            onSelected: (action) =>
                _handleAction(context, ref, widget.repoId, action),
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
              ref.invalidate(repoDetailProvider(widget.repoId));
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
                              child: RepoConfigEditorContent(
                                key: _configEditorKey,
                                initialConfig: repo.config,
                                servers: servers,
                                builders: builders,
                                gitProviders: gitProviders,
                                onDirtyChanged: (dirty) {
                                  syncDirtySnackBar(
                                    dirty: dirty,
                                    onDiscard: () => _discardConfig(repo),
                                    onSave: () => _saveConfig(repo: repo),
                                    saveEnabled: !_configSaveInFlight,
                                  );
                                },
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

  void _discardConfig(KomodoRepo repo) {
    _configEditorKey.currentState?.resetTo(repo.config);
    hideDirtySnackBar();
  }

  Future<void> _saveConfig({required KomodoRepo repo}) async {
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

    final actions = ref.read(repoActionsProvider.notifier);
    setState(() => _configSaveInFlight = true);
    final updated = await actions.updateRepoConfig(
      repoId: repo.id,
      partialConfig: partialConfig,
    );
    if (!mounted) return;
    setState(() => _configSaveInFlight = false);

    if (updated != null) {
      ref
        ..invalidate(repoDetailProvider(widget.repoId))
        ..invalidate(repoDetailProvider(repo.id))
        ..invalidate(reposProvider);

      _configEditorKey.currentState?.resetTo(updated.config);
      hideDirtySnackBar();
      AppSnackBar.show(context, 'Repo updated', tone: AppSnackBarTone.success);
      return;
    }

    final err = ref.read(repoActionsProvider).asError?.error;
    AppSnackBar.show(
      context,
      err != null ? 'Failed: $err' : 'Failed to update repo',
      tone: AppSnackBarTone.error,
    );

    reShowDirtySnackBarIfStillDirty(
      isStillDirty: () {
        return _configEditorKey.currentState
                ?.buildPartialConfigParams()
                .isNotEmpty ??
            false;
      },
      onDiscard: () => _discardConfig(repo),
      onSave: () => _saveConfig(repo: repo),
      saveEnabled: !_configSaveInFlight,
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
      footer: DetailPillList(items: repo.tags, emptyLabel: 'No tags'),
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
