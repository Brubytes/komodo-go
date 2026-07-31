import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_name_resolver_provider.dart';
import 'package:komodo_go/composition/stacks/stack_updates_provider.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/features/notifications/presentation/views/notifications/notifications_sections.dart'
    show
        NotificationsEmptyState,
        NotificationsErrorState,
        PaginationFooter,
        UpdateTile;
import 'package:komodo_go/shared/resources/providers/resource_name_resolver_provider.dart';

class StackUpdatesTab extends ConsumerWidget {
  const StackUpdatesTab({required this.stackId, super.key});

  final String stackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stackUpdatesAsync = ref.watch(stackUpdatesProvider(stackId));

    return ProviderScope(
      overrides: [
        resourceNameResolverProvider.overrideWith(
          (ref) => ref.watch(composedResourceNameResolverProvider),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          await ref.read(stackUpdatesProvider(stackId).notifier).refresh();
        },
        child: stackUpdatesAsync.when(
          data: (state) {
            if (state.items.isEmpty) {
              return DetailTabScrollView.box(
                child: const NotificationsEmptyState(
                  icon: AppIcons.updateAvailable,
                  title: 'No updates',
                  description: 'No recent activity for this stack.',
                ),
              );
            }

            final itemCount =
                state.items.length + (state.nextPage == null ? 0 : 1);
            final sliverChildCount = itemCount == 0 ? 0 : itemCount * 2 - 1;

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 200) {
                  unawaited(
                    ref
                        .read(stackUpdatesProvider(stackId).notifier)
                        .fetchNextPage(),
                  );
                }
                return false;
              },
              child: DetailTabScrollView(
                scrollKey: PageStorageKey('stack_${stackId}_updates'),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index.isOdd) return const Gap(12);

                    final itemIndex = index ~/ 2;
                    final isFooter = itemIndex >= state.items.length;
                    if (isFooter) {
                      return PaginationFooter(
                        isLoading: state.isLoadingMore,
                        onLoadMore: () => ref
                            .read(stackUpdatesProvider(stackId).notifier)
                            .fetchNextPage(),
                      );
                    }

                    final update = state.items[itemIndex];
                    return UpdateTile(update: update);
                  }, childCount: sliverChildCount),
                ),
              ),
            );
          },
          loading: () => DetailTabScrollView.box(
            padding: EdgeInsets.zero,
            child: const AppSkeletonList(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            ),
          ),
          error: (error, _) => DetailTabScrollView.box(
            padding: EdgeInsets.zero,
            child: NotificationsErrorState(
              title: 'Failed to load updates',
              message: error.toString(),
              onRetry: () => ref.invalidate(stackUpdatesProvider(stackId)),
            ),
          ),
        ),
      ),
    );
  }
}
