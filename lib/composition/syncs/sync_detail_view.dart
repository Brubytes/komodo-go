import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_advanced_menu.dart';
import 'package:komodo_go/composition/syncs/advanced_sync_section.dart';
import 'package:komodo_go/composition/syncs/sync_detail_sections.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/router/resource_routes.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/utils/relative_time.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/providers/data/models/git_provider_account.dart';
import 'package:komodo_go/features/providers/presentation/providers/git_providers_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_metadata.dart';

/// View displaying detailed sync information.
class SyncDetailView extends ConsumerStatefulWidget {
  const SyncDetailView({
    required this.syncId,
    required this.syncName,
    super.key,
  });

  final String syncId;
  final String syncName;

  @override
  ConsumerState<SyncDetailView> createState() => _SyncDetailViewState();
}

class _SyncDetailViewState extends ConsumerState<SyncDetailView>
    with DetailDirtySnackBarMixin<SyncDetailView> {
  final _configEditorKey = GlobalKey<SyncConfigEditorContentState>();
  var _configSaveInFlight = false;

  @override
  Widget build(BuildContext context) {
    final syncAsync = ref.watch(syncDetailProvider(widget.syncId));
    final actionsState = ref.watch(syncActionsProvider);
    final reposAsync = ref.watch(reposProvider);
    final gitProvidersAsync = ref.watch(gitProvidersProvider);
    final scheme = Theme.of(context).colorScheme;
    final sync = syncAsync.asData?.value;

    final repos = reposAsync.asData?.value ?? const <RepoListItem>[];
    final gitProviders =
        gitProvidersAsync.asData?.value ?? const <GitProviderAccount>[];

    String? repoNameForId(String repoId) {
      if (repoId.isEmpty) return null;
      for (final r in repos) {
        if (r.id == repoId) return r.name;
      }
      return null;
    }

    ResourceSyncState? listState;
    final syncList = ref.watch(syncsProvider).asData?.value;
    if (syncList != null) {
      for (final s in syncList) {
        if (s.id == widget.syncId) {
          listState = s.info.state;
          break;
        }
      }
    }

    return Scaffold(
      appBar: MainAppBar(
        title: widget.syncName,
        icon: AppIcons.syncs,
        markColor: AppTokens.resourceSyncs,
        markUseGradient: true,
        centerTitle: true,
        status: sync == null ? null : _syncAppBarStatus(sync, listState),
        actions: [
          if (sync != null)
            ResourceAdvancedMenuButton(
              metadata: ResourceMetadata(
                kind: ResourceKind.syncs,
                id: sync.id,
                name: sync.name,
                description: sync.description,
                template: sync.template,
                tags: sync.tags,
              ),
              onMutated: () {
                ref
                  ..invalidate(syncsProvider)
                  ..invalidate(syncDetailProvider(widget.syncId));
              },
            ),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Refresh proposed sync plan',
            onPressed: actionsState.isLoading
                ? null
                : () => _previewSync(widget.syncId),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(syncDetailProvider(widget.syncId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                syncAsync.when(
                  data: (sync) => sync != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SyncHeader(
                              syncResource: sync,
                              repoName: repoNameForId(
                                sync.config.linkedRepo.trim(),
                              ),
                              onRepoTap: sync.config.linkedRepo.trim().isEmpty
                                  ? null
                                  : () => context.push(
                                      resourceDetailRoute(
                                        AppRoutes.repos,
                                        sync.config.linkedRepo.trim(),
                                        name: repoNameForId(
                                          sync.config.linkedRepo.trim(),
                                        ),
                                      ),
                                    ),
                              onRetryPreview: () => _previewSync(sync.id),
                            ),
                            const Gap(16),
                            SyncConfigEditorContent(
                              key: _configEditorKey,
                              initialConfig: sync.config,
                              repos: repos,
                              gitProviders: gitProviders,
                              onDirtyChanged: (dirty) {
                                syncDirtySnackBar(
                                  dirty: dirty,
                                  onDiscard: () => _discardConfig(sync),
                                  onSave: () => _saveConfig(sync: sync),
                                );
                              },
                            ),
                            const Gap(16),
                            AdvancedSyncSection(
                              syncResource: sync,
                              onUpdated: (_) {
                                ref
                                  ..invalidate(syncDetailProvider(sync.id))
                                  ..invalidate(syncsProvider);
                              },
                            ),
                            const Gap(16),
                            _LastSyncContent(syncResource: sync),
                            if (sync.info.pendingError != null &&
                                sync.info.pendingError!.trim().isNotEmpty) ...[
                              const Gap(16),
                              DetailSection(
                                title: 'Pending Error',
                                icon: AppIcons.error,
                                child: _ErrorContent(syncResource: sync),
                              ),
                            ],
                          ],
                        )
                      : const _MessageSurface(message: 'Sync not found'),
                  loading: () => const _LoadingSurface(),
                  error: (error, _) => _ErrorSurface(error: error.toString()),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: scheme.scrim.withValues(alpha: 0.25),
              child: const Center(child: AppSkeletonCard()),
            ),
        ],
      ),
    );
  }

  void _discardConfig(KomodoResourceSync sync) {
    _configEditorKey.currentState?.resetTo(sync.config);
    hideDirtySnackBar();
  }

  Future<void> _saveConfig({required KomodoResourceSync sync}) async {
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

    final actions = ref.read(syncActionsProvider.notifier);
    _configSaveInFlight = true;
    final updated = await actions.updateSyncConfig(
      syncId: sync.id,
      partialConfig: partialConfig,
    );
    _configSaveInFlight = false;

    if (!mounted) return;

    final success = updated != null;
    if (success) {
      ref
        ..invalidate(syncDetailProvider(sync.id))
        ..invalidate(syncsProvider);

      _configEditorKey.currentState?.resetTo(updated.config);
      hideDirtySnackBar();
    }

    if (!mounted) return;

    AppSnackBar.show(
      context,
      success ? 'Config saved.' : 'Failed to save config.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );

    if (!success) {
      // AppSnackBar replaces the current snackbar; re-show the persistent
      // Save/Discard bar if we are still dirty.
      reShowDirtySnackBarIfStillDirty(
        isStillDirty: () {
          return _configEditorKey.currentState
                  ?.buildPartialConfigParams()
                  .isNotEmpty ??
              false;
        },
        onDiscard: () => _discardConfig(sync),
        onSave: () => _saveConfig(sync: sync),
      );
    }
  }

  Future<void> _previewSync(String syncId) async {
    final actions = ref.read(syncActionsProvider.notifier);
    final updated = await actions.refreshPending(syncId);

    if (!mounted) return;

    if (updated != null) {
      ref
        ..invalidate(syncDetailProvider(syncId))
        ..invalidate(syncsProvider);
    }

    AppSnackBar.show(
      context,
      updated != null
          ? 'Proposed sync plan refreshed below.'
          : 'Failed to refresh sync plan.',
      tone: updated != null ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}

// Header
PillTone _syncStateTone(ResourceSyncState state) => switch (state) {
  ResourceSyncState.ok => PillTone.success,
  ResourceSyncState.failed => PillTone.alert,
  ResourceSyncState.pending || ResourceSyncState.syncing => PillTone.warning,
  ResourceSyncState.unknown => PillTone.neutral,
};

int _pendingChangeCount(KomodoResourceSync sync) =>
    sync.info.resourceUpdates.length +
    sync.info.variableUpdates.length +
    sync.info.userGroupUpdates.length;

ResourceSyncState _effectiveSyncState(
  KomodoResourceSync sync,
  ResourceSyncState? listState,
) {
  if (listState != null && listState != ResourceSyncState.unknown) {
    return listState;
  }
  if ((sync.info.pendingError ?? '').trim().isNotEmpty) {
    return ResourceSyncState.failed;
  }
  if (_pendingChangeCount(sync) > 0) return ResourceSyncState.pending;
  return sync.info.lastSyncTs > 0
      ? ResourceSyncState.ok
      : ResourceSyncState.unknown;
}

MainAppBarStatus? _syncAppBarStatus(
  KomodoResourceSync sync,
  ResourceSyncState? listState,
) {
  final state = _effectiveSyncState(sync, listState);
  final synced = sync.info.lastSyncTs > 0
      ? ' · synced ${formatTimeAgo(sync.info.lastSyncTs)}'
      : '';
  return MainAppBarStatus(
    label: '${state.displayName}$synced',
    tone: _syncStateTone(state),
  );
}

class _SyncHeader extends StatelessWidget {
  const _SyncHeader({
    required this.syncResource,
    required this.repoName,
    required this.onRepoTap,
    required this.onRetryPreview,
  });

  final KomodoResourceSync syncResource;
  final String? repoName;
  final VoidCallback? onRepoTap;
  final VoidCallback onRetryPreview;

  @override
  Widget build(BuildContext context) {
    final config = syncResource.config;
    final repoLabel = (repoName ?? '').isNotEmpty ? repoName! : config.repo;
    final branch = config.branch.trim();
    final path = config.resourcePath.join('/');

    return DetailResourceHeader(
      banner: _banner(),
      facts: [
        if (repoLabel.isNotEmpty)
          DetailFact(
            icon: AppIcons.repos,
            label: 'Repository',
            value: branch.isNotEmpty ? '$repoLabel ($branch)' : repoLabel,
            onTap: onRepoTap,
          ),
        if (path.isNotEmpty)
          DetailFact(
            icon: AppIcons.package,
            label: 'Path',
            value: path,
            fullValue: path,
          ),
      ],
      tags: syncResource.tags,
      description: syncResource.description,
    );
  }

  Widget? _banner() {
    final error = syncResource.info.pendingError?.trim() ?? '';
    if (error.isNotEmpty) {
      return DetailAttentionBanner(
        icon: AppIcons.error,
        message: 'Sync plan failed',
        tone: PillTone.alert,
        actionLabel: 'Retry',
        onAction: onRetryPreview,
      );
    }
    final pending = _pendingChangeCount(syncResource);
    if (pending > 0) {
      return DetailAttentionBanner(
        icon: AppIcons.warning,
        message: '$pending pending change${pending == 1 ? '' : 's'}',
      );
    }
    return null;
  }
}

// Last Sync Content
class _LastSyncContent extends StatelessWidget {
  const _LastSyncContent({required this.syncResource});

  final KomodoResourceSync syncResource;

  @override
  Widget build(BuildContext context) {
    final info = syncResource.info;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSubCard(
          title: 'Last Sync',
          icon: AppIcons.clock,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailKeyValueRow(
                label: 'Timestamp',
                value: _formatLocalTimestamp(info.lastSyncTs),
              ),
              if (info.lastSyncHash != null)
                DetailKeyValueRow(label: 'Hash', value: info.lastSyncHash!),
              if (info.lastSyncMessage != null &&
                  info.lastSyncMessage!.isNotEmpty)
                DetailKeyValueRow(
                  label: 'Message',
                  value: info.lastSyncMessage!,
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatLocalTimestamp(int timestamp) {
    if (timestamp <= 0) return '—';
    final ms = timestamp > 1000000000000 ? timestamp : timestamp * 1000;
    final date = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    final ss = date.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }
}

// Error Content
class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.syncResource});

  final KomodoResourceSync syncResource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = syncResource.info.pendingError;

    if (error == null || error.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: AppCardSurface(
        padding: const EdgeInsets.all(12),
        radius: 12,
        child: SelectableText(
          error.trim(),
          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ),
    );
  }
}

// Helper Surfaces
class _MessageSurface extends StatelessWidget {
  const _MessageSurface({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: Text(message)),
      ),
    );
  }
}

class _LoadingSurface extends StatelessWidget {
  const _LoadingSurface();

  @override
  Widget build(BuildContext context) {
    return const AppSkeletonSurface();
  }
}

class _ErrorSurface extends StatelessWidget {
  const _ErrorSurface({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $error'),
      ),
    );
  }
}
