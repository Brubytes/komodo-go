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
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/actions/presentation/widgets/action_card.dart';

class ActionsListContent extends ConsumerWidget {
  const ActionsListContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsAsync = ref.watch(actionsProvider);
    final actionsState = ref.watch(actionActionsProvider);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.read(actionsProvider.notifier).refresh(),
          child: actionsAsync.when(
            data: (actions) {
              if (actions.isEmpty) {
                return const _EmptyState();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: actions.length,
                separatorBuilder: (context, index) => const Gap(12),
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return AppFadeSlide(
                    delay: AppMotion.stagger(index),
                    play: index < 10,
                    child: ActionCard(
                      action: action,
                      onTap: () => context.push(
                        '${AppRoutes.actions}/${action.id}?name=${Uri.encodeComponent(action.name)}',
                      ),
                      onRun: () => _runAction(context, ref, action.id),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => ErrorStateView(
              title: 'Failed to load actions',
              message: error.toString(),
              onRetry: () => ref.invalidate(actionsProvider),
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

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    String actionId,
  ) async {
    final actions = ref.read(actionActionsProvider.notifier);
    final success = await actions.run(actionId);

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success ? 'Action started' : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }
}

/// View displaying the list of all actions.
class ActionsListView extends StatelessWidget {
  const ActionsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: MainAppBar(
        title: 'Actions',
        icon: AppIcons.actions,
        markColor: AppTokens.resourceActions,
        markUseGradient: true,
        centerTitle: true,
      ),
      body: ActionsListContent(),
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
            AppIcons.actions,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const Gap(16),
          Text(
            'No actions found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(8),
          Text(
            'Create actions in the Komodo web interface',
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
