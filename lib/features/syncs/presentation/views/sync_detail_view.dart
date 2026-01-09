import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';

/// View displaying detailed sync information.
class SyncDetailView extends ConsumerWidget {
  const SyncDetailView({
    required this.syncId,
    required this.syncName,
    super.key,
  });

  final String syncId;
  final String syncName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(syncDetailProvider(syncId));
    final actionsState = ref.watch(syncActionsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: MainAppBar(
        title: syncName,
        icon: AppIcons.syncs,
        markColor: AppTokens.resourceSyncs,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.play),
            tooltip: 'Run',
            onPressed: () => _runSync(context, ref, syncId),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(syncDetailProvider(syncId));
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
                              child: _SyncConfigContent(syncResource: sync),
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

  Future<void> _runSync(
    BuildContext context,
    WidgetRef ref,
    String syncId,
  ) async {
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

// Configuration Content
class _SyncConfigContent extends StatelessWidget {
  const _SyncConfigContent({required this.syncResource});

  final KomodoResourceSync syncResource;

  @override
  Widget build(BuildContext context) {
    final config = syncResource.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailKeyValueRow(
          label: 'Managed',
          value: config.managed ? 'Yes' : 'No',
        ),
        DetailKeyValueRow(label: 'Delete', value: config.delete ? 'Yes' : 'No'),
        DetailKeyValueRow(
          label: 'Webhook',
          value: config.webhookEnabled ? 'Enabled' : 'Disabled',
        ),
        if (config.webhookSecret.isNotEmpty)
          const DetailKeyValueRow(label: 'Webhook Secret', value: 'Configured'),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        error.trim(),
        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
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
