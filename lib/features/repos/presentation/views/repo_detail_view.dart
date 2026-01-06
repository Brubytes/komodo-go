import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/models/repo.dart';
import '../providers/repos_provider.dart';
import '../widgets/repo_card.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(repoName),
        actions: [
          PopupMenuButton<RepoAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) => _handleAction(context, ref, repoId, action),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: RepoAction.clone,
                child: ListTile(
                  leading: Icon(Icons.download, color: Colors.blue),
                  title: Text('Clone'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: RepoAction.pull,
                child: ListTile(
                  leading: Icon(Icons.refresh, color: Colors.green),
                  title: Text('Pull'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: RepoAction.build,
                child: ListTile(
                  leading: Icon(Icons.build, color: Colors.orange),
                  title: Text('Build'),
                  contentPadding: EdgeInsets.zero,
                ),
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
              padding: const EdgeInsets.all(16),
              children: [
                repoAsync.when(
                  data: (repo) => repo != null
                      ? _RepoInfoCard(repo: repo)
                      : const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Repo not found'),
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
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

class _RepoInfoCard extends StatelessWidget {
  const _RepoInfoCard({required this.repo});

  final KomodoRepo repo;

  @override
  Widget build(BuildContext context) {
    final config = repo.config;
    final info = repo.info;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Repo Information',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _InfoRow(label: 'Name', value: repo.name),
            if (config.repo.isNotEmpty)
              _InfoRow(
                label: 'Repo',
                value: config.branch.isNotEmpty
                    ? '${config.repo} (${config.branch})'
                    : config.repo,
              ),
            _InfoRow(label: 'Server ID', value: config.serverId),
            _InfoRow(label: 'Builder ID', value: config.builderId),
            if (config.path.isNotEmpty) _InfoRow(label: 'Path', value: config.path),
            _InfoRow(
              label: 'Webhook',
              value: config.webhookEnabled ? 'Enabled' : 'Disabled',
            ),
            const Gap(12),
            Text(
              'Hashes',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(8),
            if (info.latestHash != null)
              _InfoRow(label: 'Latest', value: info.latestHash!),
            if (info.builtHash != null)
              _InfoRow(label: 'Built', value: info.builtHash!),
            if (info.latestMessage != null && info.latestMessage!.isNotEmpty)
              _InfoRow(label: 'Latest msg', value: info.latestMessage!),
            if (info.builtMessage != null && info.builtMessage!.isNotEmpty)
              _InfoRow(label: 'Built msg', value: info.builtMessage!),
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
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.7,
                    ),
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

