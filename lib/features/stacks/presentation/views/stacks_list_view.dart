import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/stacks/presentation/widgets/stack_card.dart';

class StacksListContent extends ConsumerWidget {
  const StacksListContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stacksAsync = ref.watch(stacksProvider);
    final actionsState = ref.watch(stackActionsProvider);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.read(stacksProvider.notifier).refresh(),
          child: stacksAsync.when(
            data: (stacks) {
              if (stacks.isEmpty) {
                return const _EmptyState();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: stacks.length,
                separatorBuilder: (context, index) => const Gap(12),
                itemBuilder: (context, index) {
                  final stackItem = stacks[index];
                  return StackCard(
                    stack: stackItem,
                    onTap: () => context.push(
                      '${AppRoutes.stacks}/${stackItem.id}?name=${Uri.encodeComponent(stackItem.name)}',
                    ),
                    onAction: (action) =>
                        _handleAction(context, ref, stackItem.id, action),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => ErrorStateView(
              title: 'Failed to load stacks',
              message: error.toString(),
              onRetry: () => ref.invalidate(stacksProvider),
            ),
          ),
        ),
        if (actionsState.isLoading)
          const ColoredBox(
            color: Colors.black26,
            child: Center(
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
    String stackId,
    StackAction action,
  ) async {
    final actions = ref.read(stackActionsProvider.notifier);
    if (action == StackAction.destroy) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Destroy stack?'),
          content: const Text(
            'This will run docker compose down and remove the stack containers. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Destroy'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final success = await switch (action) {
      StackAction.redeploy => actions.deploy(stackId),
      StackAction.pullImages => actions.pullImages(stackId),
      StackAction.restart => actions.restart(stackId),
      StackAction.pause => actions.pause(stackId),
      StackAction.start => actions.start(stackId),
      StackAction.stop => actions.stop(stackId),
      StackAction.destroy => actions.destroy(stackId),
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

/// View displaying the list of all stacks.
class StacksListView extends StatelessWidget {
  const StacksListView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: MainAppBar(
        title: 'Stacks',
        icon: AppIcons.stacks,
        markColor: AppTokens.resourceStacks,
        markUseGradient: true,
        centerTitle: true,
      ),
      body: StacksListContent(),
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
            AppIcons.stacks,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const Gap(16),
          Text(
            'No stacks found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(8),
          Text(
            'Create stacks in the Komodo web interface',
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
