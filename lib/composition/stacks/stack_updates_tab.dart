import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_name_resolver_provider.dart';
import 'package:komodo_go/composition/stacks/stack_updates_provider.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/async/async_content.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart'
    show UpdatesState;
import 'package:komodo_go/features/notifications/presentation/views/notifications/notifications_sections.dart'
    show NotificationsEmptyState, PaginationFooter, UpdateTile;
import 'package:komodo_go/shared/resources/providers/resource_name_resolver_provider.dart';

class StackUpdatesTab extends ConsumerStatefulWidget {
  const StackUpdatesTab({required this.stackId, super.key});

  final String stackId;

  @override
  ConsumerState<StackUpdatesTab> createState() => _StackUpdatesTabState();
}

class _StackUpdatesTabState extends ConsumerState<StackUpdatesTab> {
  /// Pull-to-refresh running: its spinner replaces the thin progress bar.
  var _pulling = false;

  String get stackId => widget.stackId;

  Future<void> _pull() async {
    setState(() => _pulling = true);
    try {
      await ref.read(stackUpdatesProvider(stackId).notifier).refresh();
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stackUpdatesAsync = ref.watch(stackUpdatesProvider(stackId));

    return ProviderScope(
      overrides: [
        resourceNameResolverProvider.overrideWith(
          (ref) => ref.watch(composedResourceNameResolverProvider),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _pull,
        child: NotificationListener<ScrollNotification>(
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
            sliver: SliverAsyncContent<UpdatesState>(
              value: stackUpdatesAsync,
              errorTitle: 'Failed to load updates',
              onRetry: () => ref.invalidate(stackUpdatesProvider(stackId)),
              showProgress: !_pulling,
              bannerPadding: const EdgeInsets.only(bottom: 12),
              skeletonBuilder: (_) => const Column(
                children: [
                  AppSkeletonCard(showChips: false),
                  Gap(12),
                  AppSkeletonCard(showChips: false),
                  Gap(12),
                  AppSkeletonCard(showChips: false),
                ],
              ),
              builder: (context, state) {
                if (state.items.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: NotificationsEmptyState(
                      icon: AppIcons.updateAvailable,
                      title: 'No updates',
                      description: 'No recent activity for this stack.',
                      scrollable: false,
                    ),
                  );
                }

                final itemCount =
                    state.items.length + (state.nextPage == null ? 0 : 1);
                final sliverChildCount = itemCount * 2 - 1;

                return SliverList(
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
                    return UpdateTile(update: update, currentTargetId: stackId);
                  }, childCount: sliverChildCount),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
