import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import '../../data/models/stack.dart';
import '../providers/stacks_provider.dart';
import '../widgets/stack_card.dart';

/// View displaying detailed stack information.
class StackDetailView extends ConsumerWidget {
  const StackDetailView({
    required this.stackId,
    required this.stackName,
    super.key,
  });

  final String stackId;
  final String stackName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stackAsync = ref.watch(stackDetailProvider(stackId));
    final servicesAsync = ref.watch(stackServicesProvider(stackId));
    final logAsync = ref.watch(stackLogProvider(stackId));
    final actionsState = ref.watch(stackActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(stackName),
        actions: [
          PopupMenuButton<StackAction>(
            icon: const Icon(AppIcons.moreVertical),
            onSelected: (action) =>
                _handleAction(context, ref, stackId, action),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: StackAction.deploy,
                child: ListTile(
                  leading: Icon(AppIcons.deployments, color: Colors.blue),
                  title: Text('Deploy'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: StackAction.start,
                child: ListTile(
                  leading: Icon(AppIcons.play, color: Colors.green),
                  title: Text('Start'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: StackAction.stop,
                child: ListTile(
                  leading: Icon(AppIcons.stop, color: Colors.orange),
                  title: Text('Stop'),
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
              ref.invalidate(stackDetailProvider(stackId));
              ref.invalidate(stackServicesProvider(stackId));
              ref.invalidate(stackLogProvider(stackId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                stackAsync.when(
                  data: (stack) => stack != null
                      ? _StackInfoCard(stack: stack)
                      : const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Stack not found'),
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
                const Gap(16),
                Text(
                  'Services',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(8),
                servicesAsync.when(
                  data: (services) {
                    if (services.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No services found'),
                        ),
                      );
                    }
                    return Column(
                      children: services
                          .map((service) => _StackServiceTile(service: service))
                          .toList(),
                    );
                  },
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (error, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Services unavailable: $error'),
                    ),
                  ),
                ),
                const Gap(16),
                Text(
                  'Logs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(8),
                logAsync.when(
                  data: (log) => _StackLogCard(log: log),
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (error, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Logs unavailable: $error'),
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
    String stackId,
    StackAction action,
  ) async {
    final actions = ref.read(stackActionsProvider.notifier);
    final success = await switch (action) {
      StackAction.deploy => actions.deploy(stackId),
      StackAction.start => actions.start(stackId),
      StackAction.stop => actions.stop(stackId),
    };

    if (success) {
      ref.invalidate(stackDetailProvider(stackId));
      ref.invalidate(stackServicesProvider(stackId));
      ref.invalidate(stackLogProvider(stackId));
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

class _StackInfoCard extends StatelessWidget {
  const _StackInfoCard({required this.stack});

  final KomodoStack stack;

  @override
  Widget build(BuildContext context) {
    final config = stack.config;
    final info = stack.info;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stack Information',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _InfoRow(label: 'Name', value: stack.name),
            _InfoRow(label: 'Server ID', value: config.serverId),
            if (config.repo.isNotEmpty)
              _InfoRow(
                label: 'Repo',
                value: config.branch.isNotEmpty
                    ? '${config.repo} (${config.branch})'
                    : config.repo,
              ),
            if (config.projectName.isNotEmpty)
              _InfoRow(label: 'Project', value: config.projectName),
            if (config.runDirectory.isNotEmpty)
              _InfoRow(label: 'Directory', value: config.runDirectory),
            if (info.latestHash != null)
              _InfoRow(label: 'Latest hash', value: info.latestHash!),
            if (info.deployedHash != null)
              _InfoRow(label: 'Deployed hash', value: info.deployedHash!),
            if (info.missingFiles.isNotEmpty)
              _InfoRow(
                label: 'Missing files',
                value: info.missingFiles.join(', '),
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

class _StackServiceTile extends StatelessWidget {
  const _StackServiceTile({required this.service});

  final StackService service;

  @override
  Widget build(BuildContext context) {
    final container = service.container;
    final status = container?.status ?? '';
    final state = container?.state ?? '';
    final hasUpdate = service.updateAvailable;

    final subtitleParts = <String>[
      if (state.isNotEmpty) state,
      if (status.isNotEmpty) status,
    ];

    return Card(
      child: ListTile(
        leading: Icon(
          hasUpdate ? AppIcons.updateAvailable : AppIcons.widgets,
          color: hasUpdate ? Colors.orange : null,
        ),
        title: Text(service.service),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(subtitleParts.join(' · ')),
        trailing: hasUpdate
            ? const Icon(AppIcons.dot, size: 10, color: Colors.orange)
            : null,
      ),
    );
  }
}

class _StackLogCard extends StatelessWidget {
  const _StackLogCard({required this.log});

  final StackLog? log;

  @override
  Widget build(BuildContext context) {
    final log = this.log;
    if (log == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No logs available'),
        ),
      );
    }

    final output = [
      if (log.stdout.trim().isNotEmpty) log.stdout.trim(),
      if (log.stderr.trim().isNotEmpty) log.stderr.trim(),
    ].join('\n');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log.stage.isNotEmpty ? log.stage : 'Log',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (log.command.isNotEmpty) ...[
              const Gap(4),
              Text(
                log.command,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
            const Gap(12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                output.isNotEmpty ? output : 'No output',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
