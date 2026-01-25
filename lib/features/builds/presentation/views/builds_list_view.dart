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
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/builds/presentation/widgets/build_card.dart';

class BuildsListContent extends ConsumerWidget {
  const BuildsListContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildsAsync = ref.watch(buildsProvider);
    final actionsState = ref.watch(buildActionsProvider);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.read(buildsProvider.notifier).refresh(),
          child: buildsAsync.when(
            data: (builds) {
              if (builds.isEmpty) {
                return const _EmptyState();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: builds.length,
                separatorBuilder: (context, index) => const Gap(12),
                itemBuilder: (context, index) {
                  final build = builds[index];
                  return AppFadeSlide(
                    delay: AppMotion.stagger(index),
                    play: index < 10,
                    child: BuildCard(
                      buildItem: build,
                      onTap: () => context.push(
                        '${AppRoutes.builds}/${build.id}?name=${Uri.encodeComponent(build.name)}',
                      ),
                      onAction: (action) =>
                          _handleAction(context, ref, build.id, action),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => ErrorStateView(
              title: 'Failed to load builds',
              message: error.toString(),
              onRetry: () => ref.invalidate(buildsProvider),
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
    String buildId,
    BuildAction action,
  ) async {
    final actions = ref.read(buildActionsProvider.notifier);
    final success = await switch (action) {
      BuildAction.run => actions.run(buildId),
      BuildAction.cancel => actions.cancel(buildId),
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

/// View displaying the list of all builds.
class BuildsListView extends StatelessWidget {
  const BuildsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: MainAppBar(
        title: 'Builds',
        icon: AppIcons.builds,
        markColor: AppTokens.resourceBuilds,
        markUseGradient: true,
        centerTitle: true,
      ),
      body: BuildsListContent(),
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
            AppIcons.builds,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const Gap(16),
          Text(
            'No builds found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(8),
          Text(
            'Create builds in the Komodo web interface',
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
