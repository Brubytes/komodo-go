import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';

import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/deployments/presentation/widgets/deployment_card.dart';

class DeploymentsListContent extends ConsumerWidget {
  const DeploymentsListContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deploymentsAsync = ref.watch(deploymentsProvider);
    final actionsState = ref.watch(deploymentActionsProvider);

    return Stack(
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
                  return AppFadeSlide(
                    delay: AppMotion.stagger(index),
                    play: index < 10,
                    child: DeploymentCard(
                      deployment: deployment,
                      onTap: () => context.go(
                        '${AppRoutes.deployments}/${deployment.id}?name=${Uri.encodeComponent(deployment.name)}',
                      ),
                      onAction: (action) =>
                          _handleAction(context, ref, deployment.id, action),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => ErrorStateView(
              title: 'Failed to load deployments',
              message: error.toString(),
              onRetry: () => ref.invalidate(deploymentsProvider),
            ),
          ),
        ),

        // Loading overlay for actions
        if (actionsState.isLoading)
          ColoredBox(
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.25),
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
          key: ValueKey('deployment_destroy_dialog_$deploymentId'),
          title: const Text('Destroy Deployment'),
          content: const Text(
            'Are you sure you want to destroy this deployment? '
            'This will stop and remove the container.',
          ),
          actions: [
            TextButton(
              key: ValueKey('deployment_destroy_cancel_$deploymentId'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: ValueKey('deployment_destroy_confirm_$deploymentId'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Destroy'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final actions = ref.read(deploymentActionsProvider.notifier);
    final success = await switch (action) {
      DeploymentAction.deploy => actions.deploy(deploymentId),
      DeploymentAction.pullImages => actions.pullImages(deploymentId),
      DeploymentAction.start => actions.start(deploymentId),
      DeploymentAction.stop => actions.stop(deploymentId),
      DeploymentAction.restart => actions.restart(deploymentId),
      DeploymentAction.pause => actions.pause(deploymentId),
      DeploymentAction.unpause => actions.unpause(deploymentId),
      DeploymentAction.destroy => actions.destroy(deploymentId),
    };

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success
            ? 'Action completed successfully'
            : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }
}

/// View displaying the list of all deployments.
class DeploymentsListView extends StatelessWidget {
  const DeploymentsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: MainAppBar(
        title: 'Deployments',
        icon: AppIcons.deployments,
        markColor: AppTokens.resourceDeployments,
        markUseGradient: true,
        centerTitle: true,
      ),
      body: DeploymentsListContent(),
    );
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
            AppIcons.deployments,
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
