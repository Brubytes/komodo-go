import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../providers/stacks_provider.dart';
import '../widgets/stack_card.dart';

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
            error: (error, stack) => _ErrorState(
              message: error.toString(),
              onRetry: () => ref.invalidate(stacksProvider),
            ),
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

/// View displaying the list of all stacks.
class StacksListView extends StatelessWidget {
  const StacksListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stacks')),
      body: const StacksListContent(),
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
            Icons.layers_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const Gap(16),
          Text('No stacks found', style: Theme.of(context).textTheme.titleMedium),
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
              'Failed to load stacks',
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
