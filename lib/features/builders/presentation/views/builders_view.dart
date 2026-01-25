import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';
import 'package:komodo_go/features/builders/presentation/views/builders/builder_tile.dart';
import 'package:komodo_go/features/builders/presentation/views/builders/builders_view_states.dart';

class BuildersView extends ConsumerWidget {
  const BuildersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildersAsync = ref.watch(buildersProvider);
    final actionsState = ref.watch(builderActionsProvider);

    return Scaffold(
      appBar: const MainAppBar(
        title: 'Builders',
        icon: AppIcons.factory,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(buildersProvider.notifier).refresh(),
            child: buildersAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const BuildersEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Gap(12),
                  itemBuilder: (context, index) => AppFadeSlide(
                    delay: AppMotion.stagger(index),
                    play: index < 10,
                    child: BuilderTile(item: items[index]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorStateView(
                title: 'Failed to load builders',
                message: error.toString(),
                onRetry: () => ref.invalidate(buildersProvider),
              ),
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.scrim.withValues(alpha: 0.25),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
