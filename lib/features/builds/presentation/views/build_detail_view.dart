import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/models/build.dart';
import '../providers/builds_provider.dart';
import '../widgets/build_card.dart';

/// View displaying detailed build information.
class BuildDetailView extends ConsumerWidget {
  const BuildDetailView({
    required this.buildId,
    required this.buildName,
    super.key,
  });

  final String buildId;
  final String buildName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildAsync = ref.watch(buildDetailProvider(buildId));
    final actionsState = ref.watch(buildActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(buildName),
        actions: [
          PopupMenuButton<BuildAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) => _handleAction(context, ref, buildId, action),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: BuildAction.run,
                child: ListTile(
                  leading: Icon(Icons.play_arrow, color: Colors.green),
                  title: Text('Run build'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: BuildAction.cancel,
                child: ListTile(
                  leading: Icon(Icons.stop, color: Colors.orange),
                  title: Text('Cancel'),
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
              ref.invalidate(buildDetailProvider(buildId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                buildAsync.when(
                  data: (build) => build != null
                      ? _BuildInfoCard(buildResource: build)
                      : const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Build not found'),
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
    String buildId,
    BuildAction action,
  ) async {
    final actions = ref.read(buildActionsProvider.notifier);
    final success = await switch (action) {
      BuildAction.run => actions.run(buildId),
      BuildAction.cancel => actions.cancel(buildId),
    };

    if (success) {
      ref.invalidate(buildDetailProvider(buildId));
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

class _BuildInfoCard extends StatelessWidget {
  const _BuildInfoCard({required this.buildResource});

  final KomodoBuild buildResource;

  @override
  Widget build(BuildContext context) {
    final config = buildResource.config;
    final info = buildResource.info;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Build Information',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _InfoRow(label: 'Name', value: buildResource.name),
            _InfoRow(label: 'Builder ID', value: config.builderId),
            if (config.repo.isNotEmpty)
              _InfoRow(
                label: 'Repo',
                value: config.branch.isNotEmpty
                    ? '${config.repo} (${config.branch})'
                    : config.repo,
              ),
            if (config.imageName.isNotEmpty)
              _InfoRow(label: 'Image', value: config.imageName),
            if (config.imageTag.isNotEmpty)
              _InfoRow(label: 'Tag', value: config.imageTag),
            _InfoRow(label: 'Version', value: config.version.label),
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
            const Gap(12),
            if (info.remoteError != null && info.remoteError!.trim().isNotEmpty)
              _LogCard(
                title: 'Remote error',
                content: info.remoteError!,
              ),
            if (info.builtContents != null &&
                info.builtContents!.trim().isNotEmpty)
              _LogCard(
                title: 'Built contents',
                content: info.builtContents!,
              ),
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

class _LogCard extends StatelessWidget {
  const _LogCard({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              content.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
