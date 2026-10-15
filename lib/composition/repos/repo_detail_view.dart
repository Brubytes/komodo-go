import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/repos/repo_detail_sections.dart';
import 'package:komodo_go/composition/resources/resource_manage_actions.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/router/resource_routes.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/utils/relative_time.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/empty_state_view.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';
import 'package:komodo_go/features/providers/data/models/git_provider_account.dart';
import 'package:komodo_go/features/providers/presentation/providers/git_providers_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/repos/presentation/widgets/repo_card.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_metadata.dart';

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
  var _dirty = false;

  void _onDirtyChanged(bool dirty, KomodoRepo repo) {
    _dirty = dirty;
    syncDirtySnackBar(
      dirty: dirty,
      onDiscard: () => _discardConfig(repo),
      onSave: () => _saveConfig(repo: repo),
      saving: _configSaveInFlight,
      saveEnabled: !_configSaveInFlight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(repoDetailProvider(widget.repoId));
    final actionsState = ref.watch(repoActionsProvider);
    final serversListAsync = ref.watch(serversProvider);
    final reposAsync = ref.watch(reposProvider);
    final buildersListAsync = ref.watch(buildersProvider);
    final gitProvidersAsync = ref.watch(gitProvidersProvider);

    final scheme = Theme.of(context).colorScheme;
    final repo = repoAsync.asData?.value;
    RepoListItem? listItem;
    for (final item in reposAsync.asData?.value ?? const <RepoListItem>[]) {
      if (item.id == widget.repoId) {
        listItem = item;
        break;
      }
    }

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

    final notCloned =
        listItem != null &&
        (listItem.info.clonedHash ?? '').isEmpty &&
        listItem.info.lastPulledAt == 0;
    final hasBuilder = (repo?.config.builderId ?? '').isNotEmpty;

    void retry() {
      ref.invalidate(repoDetailProvider(widget.repoId));
    }

    return UnsavedChangesGuard(
      dirty: _dirty,
      onDiscarded: hideDirtySnackBar,
      child: Scaffold(
        appBar: MainAppBar(
          title: widget.repoName,
          icon: AppIcons.repos,
          markColor: AppTokens.resourceRepos,
          markUseGradient: true,
          centerTitle: true,
          status: repoAppBarStatus(listItem: listItem, repo: repo),
        ),
        body: Stack(
          children: [
            DetailTabScaffold(
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
                        repoAsync.when(
                          data: (repo) => repo != null
                              ? _RepoHeader(
                                  repo: repo,
                                  listItem: listItem,
                                  serverName: serverNameForId(
                                    repo.config.serverId,
                                  ),
                                  onServerTap: repo.config.serverId.isEmpty
                                      ? null
                                      : () => context.push(
                                          resourceDetailRoute(
                                            AppRoutes.servers,
                                            repo.config.serverId,
                                            name: serverNameForId(
                                              repo.config.serverId,
                                            ),
                                          ),
                                        ),
                                  onPull: () => _handleAction(
                                    context,
                                    ref,
                                    widget.repoId,
                                    RepoAction.pull,
                                  ),
                                )
                              : const _MessageSurface(
                                  message: 'Repo not found',
                                ),
                          loading: () => const _LoadingSurface(),
                          error: (error, _) =>
                              _ErrorSurface(error: error, onRetry: retry),
                        ),
                        const Gap(AppSpacing.md),
                        DetailActionBar(
                          primary: notCloned
                              ? DetailActionButton(
                                  label: 'Clone',
                                  icon: AppIcons.download,
                                  onPressed: () => _handleAction(
                                    context,
                                    ref,
                                    widget.repoId,
                                    RepoAction.clone,
                                  ),
                                )
                              : DetailActionButton(
                                  label: 'Pull',
                                  icon: AppIcons.refresh,
                                  onPressed: () => _handleAction(
                                    context,
                                    ref,
                                    widget.repoId,
                                    RepoAction.pull,
                                  ),
                                ),
                          secondary: hasBuilder
                              ? DetailActionButton(
                                  label: 'Build',
                                  icon: AppIcons.builds,
                                  onPressed: () => _handleAction(
                                    context,
                                    ref,
                                    widget.repoId,
                                    RepoAction.build,
                                  ),
                                )
                              : null,
                          moreGroups: [
                            if (!notCloned && repo != null)
                              DetailActionGroup(
                                label: 'Repo',
                                items: [
                                  DetailActionItem(
                                    label: 'Clone again',
                                    icon: AppIcons.download,
                                    onSelected: () => _handleAction(
                                      context,
                                      ref,
                                      widget.repoId,
                                      RepoAction.clone,
                                    ),
                                  ),
                                ],
                              ),
                            if (repo != null)
                              buildResourceManageGroup(
                                context: context,
                                ref: ref,
                                metadata: ResourceMetadata(
                                  kind: ResourceKind.repos,
                                  id: repo.id,
                                  name: repo.name,
                                  description: repo.description,
                                  template: repo.template,
                                  tags: repo.tags,
                                ),
                                onMutated: () {
                                  ref
                                    ..invalidate(reposProvider)
                                    ..invalidate(
                                      repoDetailProvider(widget.repoId),
                                    );
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              tabs: [
                DetailTabSpec(
                  id: 'config',
                  label: 'Config',
                  icon: AppIcons.bolt,
                  body: RefreshIndicator(
                    onRefresh: () async => retry(),
                    child: DetailTabScrollView.box(
                      scrollKey: PageStorageKey('repo_${widget.repoId}_config'),
                      child: repoAsync.when(
                        data: (repo) => repo != null
                            ? RepoConfigEditorContent(
                                key: _configEditorKey,
                                initialConfig: repo.config,
                                servers: servers,
                                builders: builders,
                                gitProviders: gitProviders,
                                onDirtyChanged: (dirty) =>
                                    _onDirtyChanged(dirty, repo),
                              )
                            : const _MessageSurface(
                                message: 'Repo not found',
                              ),
                        loading: () => const _LoadingSurface(),
                        error: (error, _) =>
                            _ErrorSurface(error: error, onRetry: retry),
                      ),
                    ),
                  ),
                ),
                DetailTabSpec(
                  id: 'builds',
                  label: 'Builds',
                  icon: AppIcons.builds,
                  body: RefreshIndicator(
                    onRefresh: () async => retry(),
                    child: DetailTabScrollView.box(
                      scrollKey: PageStorageKey(
                        'repo_${widget.repoId}_build_status',
                      ),
                      child: repoAsync.when(
                        data: (repo) => repo != null
                            ? _RepoBuildContent(info: repo.info)
                            : const _MessageSurface(
                                message: 'Repo not found',
                              ),
                        loading: () => const _LoadingSurface(),
                        error: (error, _) =>
                            _ErrorSurface(error: error, onRetry: retry),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (actionsState.isLoading)
              ColoredBox(
                color: scheme.scrim.withValues(alpha: 0.25),
                child: const Center(child: AppSkeletonCard()),
              ),
          ],
        ),
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
    syncDirtySnackBar(
      dirty: true,
      onDiscard: () => _discardConfig(repo),
      onSave: () => _saveConfig(repo: repo),
      saving: true,
      saveEnabled: false,
    );
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
      _dirty = false;
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

    if (!context.mounted) return;

    if (success) {
      ref.invalidate(repoDetailProvider(repoId));
    }

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success
            ? 'Action submitted. Check updates for the result.'
            : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }
}

/// App bar status line for a repo: state plus how long ago it was pulled.
MainAppBarStatus? repoAppBarStatus({
  required RepoListItem? listItem,
  required KomodoRepo? repo,
}) {
  if (listItem == null) return null;
  final pulledAt = repo?.info.lastPulledAt ?? listItem.info.lastPulledAt;
  final ago = pulledAt > 0 ? ' · pulled ${formatTimeAgo(pulledAt)}' : '';
  return switch (listItem.info.state) {
    RepoState.ok => MainAppBarStatus(label: 'Ok$ago', tone: PillTone.success),
    RepoState.failed => MainAppBarStatus(
      label: 'Failed$ago',
      tone: PillTone.alert,
    ),
    RepoState.cloning => const MainAppBarStatus(
      label: 'Cloning',
      tone: PillTone.warning,
    ),
    RepoState.pulling => const MainAppBarStatus(
      label: 'Pulling',
      tone: PillTone.warning,
    ),
    RepoState.building => const MainAppBarStatus(
      label: 'Building',
      tone: PillTone.warning,
    ),
    RepoState.unknown => const MainAppBarStatus(label: 'Unknown'),
  };
}

class _RepoHeader extends StatelessWidget {
  const _RepoHeader({
    required this.repo,
    required this.listItem,
    required this.serverName,
    this.onServerTap,
    this.onPull,
  });

  final KomodoRepo repo;
  final RepoListItem? listItem;
  final String? serverName;
  final VoidCallback? onServerTap;
  final VoidCallback? onPull;

  @override
  Widget build(BuildContext context) {
    final config = repo.config;
    final latest = repo.info.latestHash;
    final current = listItem?.info.clonedHash ?? repo.info.builtHash;
    final state = listItem?.info.state;
    final outOfDate = latest != null && current != null && latest != current;
    final busy =
        state == RepoState.cloning ||
        state == RepoState.pulling ||
        state == RepoState.building;

    final DetailAttentionBanner? banner;
    if (state == RepoState.failed) {
      banner = DetailAttentionBanner(
        icon: AppIcons.error,
        tone: PillTone.alert,
        message: 'Last operation failed',
        actionLabel: onPull == null ? null : 'Pull',
        onAction: onPull,
      );
    } else if (outOfDate && !busy) {
      banner = DetailAttentionBanner(
        icon: AppIcons.warning,
        message: 'Repo is out of date',
        actionLabel: onPull == null ? null : 'Pull',
        onAction: onPull,
      );
    } else {
      banner = null;
    }

    return DetailResourceHeader(
      banner: banner,
      facts: [
        if (config.repo.isNotEmpty)
          DetailFact(
            icon: AppIcons.repos,
            label: 'Repo',
            value: config.branch.isEmpty
                ? config.repo
                : '${config.repo} · ${config.branch}',
            fullValue: config.branch.isEmpty
                ? config.repo
                : '${config.repo} (${config.branch})',
          ),
        if (config.serverId.isNotEmpty)
          DetailFact(
            icon: AppIcons.server,
            label: 'Server',
            value: serverName ?? config.serverId,
            onTap: onServerTap,
          ),
      ],
      tags: repo.tags,
      description: repo.description,
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
    return const AppSkeletonSurface();
  }
}

class _MessageSurface extends StatelessWidget {
  const _MessageSurface({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: EmptyStateView.inline(icon: AppIcons.info, title: message),
      ),
    );
  }
}

class _ErrorSurface extends StatelessWidget {
  const _ErrorSurface({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      child: ErrorStateView.fromError(
        title: 'Could not load repo',
        error: error,
        onRetry: onRetry,
      ),
    );
  }
}
