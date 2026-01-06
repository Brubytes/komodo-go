import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import '../../data/models/action.dart';
import '../providers/actions_provider.dart';

/// View displaying detailed action information.
class ActionDetailView extends ConsumerWidget {
  const ActionDetailView({
    required this.actionId,
    required this.actionName,
    super.key,
  });

  final String actionId;
  final String actionName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionAsync = ref.watch(actionDetailProvider(actionId));
    final actionsState = ref.watch(actionActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(actionName),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.play),
            tooltip: 'Run',
            onPressed: () => _runAction(context, ref, actionId),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(actionDetailProvider(actionId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                actionAsync.when(
                  data: (action) => action != null
                      ? _ActionInfoCard(action: action)
                      : const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Action not found'),
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

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    String actionId,
  ) async {
    final actions = ref.read(actionActionsProvider.notifier);
    final success = await actions.run(actionId);

    if (success) {
      ref.invalidate(actionDetailProvider(actionId));
      ref.invalidate(actionsProvider);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Action started' : 'Action failed. Please try again.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

class _ActionInfoCard extends StatelessWidget {
  const _ActionInfoCard({required this.action});

  final KomodoAction action;

  @override
  Widget build(BuildContext context) {
    final config = action.config;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Action',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _InfoRow(label: 'Name', value: action.name),
            if (action.description.trim().isNotEmpty)
              _InfoRow(label: 'Description', value: action.description.trim()),
            _InfoRow(
              label: 'Run at startup',
              value: config.runAtStartup ? 'Enabled' : 'Disabled',
            ),
            _InfoRow(
              label: 'Schedule',
              value: config.scheduleEnabled
                  ? (config.schedule.isNotEmpty ? config.schedule : 'Enabled')
                  : 'Disabled',
            ),
            _InfoRow(
              label: 'Arguments format',
              value: config.argumentsFormat.displayName,
            ),
            _InfoRow(
              label: 'Webhook',
              value: config.webhookEnabled ? 'Enabled' : 'Disabled',
            ),
            if (config.webhookSecret.isNotEmpty)
              const _InfoRow(label: 'Webhook secret', value: 'Configured'),
            _InfoRow(
              label: 'Reload deps',
              value: config.reloadDenoDeps ? 'Enabled' : 'Disabled',
            ),
            if (config.arguments.trim().isNotEmpty) ...[
              const Gap(12),
              Text(
                'Arguments',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Gap(8),
              _LogContent(content: config.arguments),
            ],
            if (config.fileContents.trim().isNotEmpty) ...[
              const Gap(12),
              Text(
                'File contents',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Gap(8),
              _LogContent(content: config.fileContents),
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
            width: 130,
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
