import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:komodo_go/features/syncs/presentation/widgets/sync_card.dart';

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
                  return SyncCard(
                    sync: sync,
                    onTap: () => context.push(
                      '${AppRoutes.syncs}/${sync.id}?name=${Uri.encodeComponent(sync.name)}',
                    ),
                    onRun: () => _runSync(context, ref, sync.id),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _ErrorState(
              message: error.toString(),
              onRetry: () => ref.invalidate(syncsProvider),
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
              AppIcons.formError,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const Gap(16),
            Text(
              'Failed to load syncs',
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
