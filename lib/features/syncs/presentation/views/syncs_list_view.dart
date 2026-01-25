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
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:komodo_go/features/syncs/presentation/widgets/sync_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

class SyncsListContent extends ConsumerWidget {
  const SyncsListContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncsAsync = ref.watch(syncsProvider);
    final actionsState = ref.watch(syncActionsProvider);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.read(syncsProvider.notifier).refresh(),
          child: syncsAsync.when(
            data: (syncs) {
              if (syncs.isEmpty) {
                return const _EmptyState();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: syncs.length,
                separatorBuilder: (context, index) => const Gap(12),
                itemBuilder: (context, index) {
                  final sync = syncs[index];
                  return AppFadeSlide(
                    delay: AppMotion.stagger(index),
                    play: index < 10,
                    child: SyncCard(
                      sync: sync,
                      onTap: () => context.push(
                        '${AppRoutes.syncs}/${sync.id}?name=${Uri.encodeComponent(sync.name)}',
                      ),
                      onRun: () => _runSync(context, ref, sync.id),
                    ),
                  );
                },
              );
            },
            loading: () => const _SyncsSkeletonList(),
            error: (error, stack) => ErrorStateView(
              title: 'Failed to load syncs',
              message: error.toString(),
              onRetry: () => ref.invalidate(syncsProvider),
            ),
          ),
        ),
        if (actionsState.isLoading)
          const ColoredBox(
            color: Colors.black26,
            child: Center(child: AppSkeletonCard()),
          ),
      ],
    );
  }

  Future<void> _runSync(
    BuildContext context,
    WidgetRef ref,
    String syncId,
  ) async {
    final actions = ref.read(syncActionsProvider.notifier);
    final success = await actions.run(syncId);

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success ? 'Sync started' : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }
}

/// View displaying the list of all syncs.
class SyncsListView extends StatelessWidget {
  const SyncsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: MainAppBar(
        title: 'Syncs',
        icon: AppIcons.syncs,
        markColor: AppTokens.resourceSyncs,
        markUseGradient: true,
        centerTitle: true,
      ),
      body: SyncsListContent(),
    );
  }
}

class _SyncsSkeletonList extends StatelessWidget {
  const _SyncsSkeletonList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const Gap(12),
        itemBuilder: (_, __) => AppCardSurface(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 16),
                    const Gap(10),
                    Expanded(
                      child: Text('Sync name', style: textTheme.titleSmall),
                    ),
                    const Gap(8),
                    const CircleAvatar(radius: 6),
                  ],
                ),
                const Gap(10),
                Text('Repo • Server • Schedule', style: textTheme.bodySmall),
                const Gap(10),
                Row(
                  children: const [
                    Chip(label: Text('Idle')),
                    Gap(8),
                    Chip(label: Text('Last run 2m')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
            AppIcons.syncs,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const Gap(16),
          Text(
            'No syncs found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(8),
          Text(
            'Create syncs in the Komodo web interface',
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
