import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/deployments_provider.dart';
import '../widgets/deployment_card.dart';

/// View displaying the list of all deployments.
class DeploymentsListView extends ConsumerWidget {
  const DeploymentsListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deploymentsAsync = ref.watch(deploymentsProvider);
    final actionsState = ref.watch(deploymentActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Deployments')),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(deploymentsProvider.notifier).refresh(),
            child: deploymentsAsync.when(
              data: (deployments) {
                if (deployments.isEmpty) {
                  return const _EmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: deployments.length,
                  separatorBuilder: (context, index) => const Gap(12),
                  itemBuilder: (context, index) {
                    final deployment = deployments[index];
                    return DeploymentCard(
                      deployment: deployment,
                      onAction: (action) =>
                          _handleAction(context, ref, deployment.id, action),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(deploymentsProvider),
              ),
            ),
          ),

          // Loading overlay for actions
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
    String deploymentId,
    DeploymentAction action,
  ) async {
    // Confirm destructive actions
    if (action == DeploymentAction.destroy) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Destroy Deployment'),
          content: const Text(
            'Are you sure you want to destroy this deployment? '
            'This will stop and remove the container.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Destroy'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final actions = ref.read(deploymentActionsProvider.notifier);
    final success = await switch (action) {
      DeploymentAction.start => actions.start(deploymentId),
      DeploymentAction.stop => actions.stop(deploymentId),
      DeploymentAction.restart => actions.restart(deploymentId),
      DeploymentAction.pause => actions.pause(deploymentId),
      DeploymentAction.unpause => actions.unpause(deploymentId),
      DeploymentAction.destroy => actions.destroy(deploymentId),
      DeploymentAction.deploy => actions.deploy(deploymentId),
    };

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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rocket_launch_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const Gap(16),
          Text(
            'No deployments found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(8),
          Text(
            'Create deployments in the Komodo web interface',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const Gap(16),
            Text(
              'Failed to load deployments',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
