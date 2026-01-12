import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/providers/data/models/git_provider_account.dart';
import 'package:komodo_go/features/providers/presentation/providers/git_providers_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:komodo_go/features/syncs/presentation/views/sync_detail/sync_detail_sections.dart';

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

class _SyncDetailViewState extends ConsumerState<SyncDetailView> {
  final _configEditorKey = GlobalKey<SyncConfigEditorContentState>();

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  _configDirtySnackBar;
  var _configSaveInFlight = false;

  @override
  Widget build(BuildContext context) {
    final syncAsync = ref.watch(syncDetailProvider(widget.syncId));
    final actionsState = ref.watch(syncActionsProvider);
    final reposAsync = ref.watch(reposProvider);
    final gitProvidersAsync = ref.watch(gitProvidersProvider);
    final scheme = Theme.of(context).colorScheme;

    final repos = reposAsync.asData?.value ?? const <RepoListItem>[];
    final gitProviders =
        gitProvidersAsync.asData?.value ?? const <GitProviderAccount>[];

    return Scaffold(
      appBar: MainAppBar(
        title: widget.syncName,
        icon: AppIcons.syncs,
        markColor: AppTokens.resourceSyncs,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.play),
            tooltip: 'Run',
            onPressed: () => _runSync(context, widget.syncId),
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
                            _SyncHeroPanel(syncResource: sync),
                            const Gap(16),
                            DetailSection(
                              title: 'Configuration',
                              icon: AppIcons.settings,
                              child: SyncConfigEditorContent(
                                key: _configEditorKey,
                                initialConfig: sync.config,
                                repos: repos,
                                gitProviders: gitProviders,
                                onDirtyChanged: (dirty) {
                                  _onConfigDirtyChanged(
                                    dirty: dirty,
                                    sync: sync,
                                  );
                                },
                              ),
                            ),
                            const Gap(16),
                            DetailSection(
                              title: 'Last Sync',
                              icon: AppIcons.clock,
                              child: _LastSyncContent(syncResource: sync),
                            ),
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

  void _onConfigDirtyChanged({
    required bool dirty,
    required KomodoResourceSync sync,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!dirty) {
        _hideConfigDirtySnackBar();
      } else {
        _showConfigDirtySnackBar(sync);
      }
    });
  }

  void _hideConfigDirtySnackBar() {
    if (_configDirtySnackBar == null) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _configDirtySnackBar = null;
  }

  void _showConfigDirtySnackBar(KomodoResourceSync sync) {
    if (_configDirtySnackBar != null) return;

    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    final controller = messenger.showSnackBar(
      SnackBar(
        backgroundColor: scheme.inverseSurface,
        duration: const Duration(days: 1),
        dismissDirection: DismissDirection.none,
        behavior: SnackBarBehavior.floating,
        content: DefaultTextStyle(
          style: TextStyle(color: scheme.onInverseSurface),
          child: Row(
            children: [
              const Expanded(child: Text('Unsaved changes')),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onInverseSurface,
                ),
                onPressed: () => _discardConfig(sync),
                child: const Text('Discard'),
              ),
              const Gap(8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onInverseSurface,
                ),
                onPressed: () => _saveConfig(sync: sync),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );

    _configDirtySnackBar = controller;
    controller.closed.then((_) {
      if (!mounted) return;
      if (_configDirtySnackBar == controller) {
        _configDirtySnackBar = null;
      }
    });
  }

  void _discardConfig(KomodoResourceSync sync) {
    _configEditorKey.currentState?.resetTo(sync.config);
    _hideConfigDirtySnackBar();
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
      _hideConfigDirtySnackBar();
      return;
    }

    final actions = ref.read(syncActionsProvider.notifier);
    _configSaveInFlight = true;
    final updated = await actions.updateSyncConfig(
      syncId: sync.id,
      partialConfig: partialConfig,
    );
    _configSaveInFlight = false;

    final success = updated != null;
    if (success) {
      ref
        ..invalidate(syncDetailProvider(sync.id))
        ..invalidate(syncsProvider);

      _configEditorKey.currentState?.resetTo(updated.config);
      _hideConfigDirtySnackBar();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final stillDirty =
            _configEditorKey.currentState
                ?.buildPartialConfigParams()
                .isNotEmpty ??
            false;
        if (stillDirty) _showConfigDirtySnackBar(sync);
      });
    }
  }

  Future<void> _runSync(BuildContext context, String syncId) async {
    final actions = ref.read(syncActionsProvider.notifier);
    final success = await actions.run(syncId);

    if (success) {
      ref
        ..invalidate(syncDetailProvider(syncId))
        ..invalidate(syncsProvider);
    }

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success ? 'Sync started' : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }
}

// Hero Panel
class _SyncHeroPanel extends StatelessWidget {
  const _SyncHeroPanel({required this.syncResource});

  final KomodoResourceSync syncResource;

  @override
  Widget build(BuildContext context) {
    return DetailHeroPanel(
      header: _SyncHeader(syncResource: syncResource),
      metrics: [
        if (syncResource.config.repo.isNotEmpty)
          DetailMetricTileData(
            label: 'Repository',
            value: syncResource.config.branch.isNotEmpty
                ? '${syncResource.config.repo} (${syncResource.config.branch})'
                : syncResource.config.repo,
            icon: AppIcons.repos,
            tone: DetailMetricTone.neutral,
          ),
        if (syncResource.config.resourcePath.isNotEmpty)
          DetailMetricTileData(
            label: 'Path',
            value: syncResource.config.resourcePath.join('/'),
            icon: AppIcons.repos,
            tone: DetailMetricTone.neutral,
          ),
        if (syncResource.info.lastSyncTs > 0)
          DetailMetricTileData(
            label: 'Last Synced',
            value: _formatTimestamp(syncResource.info.lastSyncTs),
            icon: AppIcons.clock,
            tone: DetailMetricTone.neutral,
          ),
      ],
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _SyncHeader extends StatelessWidget {
  const _SyncHeader({required this.syncResource});

  final KomodoResourceSync syncResource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          syncResource.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (syncResource.description.isNotEmpty) ...[
          const Gap(4),
          Text(
            syncResource.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
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
        DetailKeyValueRow(
          label: 'Timestamp',
          value: info.lastSyncTs.toString(),
        ),
        if (info.lastSyncHash != null)
          DetailKeyValueRow(label: 'Hash', value: info.lastSyncHash!),
        if (info.lastSyncMessage != null && info.lastSyncMessage!.isNotEmpty)
          DetailKeyValueRow(label: 'Message', value: info.lastSyncMessage!),
      ],
    );
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
        enableShadow: false,
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
    return const DetailSurface(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
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
