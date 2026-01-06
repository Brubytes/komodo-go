import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import '../../data/models/sync.dart';
import '../providers/syncs_provider.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(syncName),
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
              padding: const EdgeInsets.all(16),
              children: [
                syncAsync.when(
                  data: (sync) => sync != null
                      ? _SyncInfoCard(sync: sync)
                      : const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Sync not found'),
                          ),
                        ),
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (error, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: $error'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            Container(
              color: Colors.black26,
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
      ref.invalidate(syncDetailProvider(syncId));
      ref.invalidate(syncsProvider);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Sync started' : 'Action failed. Please try again.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

class _SyncInfoCard extends StatelessWidget {
  const _SyncInfoCard({required this.sync});

  final KomodoResourceSync sync;

  @override
  Widget build(BuildContext context) {
    final config = sync.config;
    final info = sync.info;

    final repoLabel = config.repo.isNotEmpty
        ? (config.branch.isNotEmpty
              ? '${config.repo} (${config.branch})'
              : config.repo)
        : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _InfoRow(label: 'Name', value: sync.name),
            if (repoLabel.isNotEmpty) _InfoRow(label: 'Repo', value: repoLabel),
            if (config.resourcePath.isNotEmpty)
              _InfoRow(label: 'Path', value: config.resourcePath.join('/')),
            _InfoRow(label: 'Managed', value: config.managed ? 'Yes' : 'No'),
            _InfoRow(label: 'Delete', value: config.delete ? 'Yes' : 'No'),
            _InfoRow(
              label: 'Webhook',
              value: config.webhookEnabled ? 'Enabled' : 'Disabled',
            ),
            if (config.webhookSecret.isNotEmpty)
              const _InfoRow(label: 'Webhook secret', value: 'Configured'),
            const Gap(12),
            Text(
              'Last sync',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Gap(8),
            _InfoRow(label: 'Timestamp', value: info.lastSyncTs.toString()),
            if (info.lastSyncHash != null)
              _InfoRow(label: 'Hash', value: info.lastSyncHash!),
            if (info.lastSyncMessage != null &&
                info.lastSyncMessage!.isNotEmpty)
              _InfoRow(label: 'Message', value: info.lastSyncMessage!),
            if (info.pendingError != null &&
                info.pendingError!.trim().isNotEmpty) ...[
              const Gap(12),
              Text(
                'Pending error',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Gap(8),
              _LogContent(content: info.pendingError!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogContent extends StatelessWidget {
  const _LogContent({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        content.trim(),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }
}
