import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_name_resolver_provider.dart';
import 'package:komodo_go/composition/stacks/stack_updates_provider.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
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
                  scrollable: false,
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
          loading: () => DetailTabScrollView.list(
            children: const [
              AppSkeletonCard(showChips: false),
              Gap(12),
              AppSkeletonCard(showChips: false),
              Gap(12),
              AppSkeletonCard(showChips: false),
              Gap(12),
              AppSkeletonCard(showChips: false),
            ],
          ),
          error: (error, _) => DetailTabScrollView.box(
            padding: EdgeInsets.zero,
            child: NotificationsErrorState(
              title: 'Failed to load updates',
              message: error.toString(),
              onRetry: () => ref.invalidate(stackUpdatesProvider(stackId)),
              scrollable: false,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact, non-scrolling "Recent activity" block for embedding in a tab.
///
/// Shows the first few updates and a "Show more" button that pages further.
class StackUpdatesSection extends ConsumerStatefulWidget {
  const StackUpdatesSection({required this.stackId, super.key});

  final String stackId;

  @override
  ConsumerState<StackUpdatesSection> createState() =>
      _StackUpdatesSectionState();
}

class _StackUpdatesSectionState extends ConsumerState<StackUpdatesSection> {
  static const _pageSize = 5;
  int _visible = _pageSize;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(stackUpdatesProvider(widget.stackId));
    final count = async.asData?.value.items.length;
    final hasMore = async.asData?.value.nextPage != null;

    return ProviderScope(
      overrides: [
        resourceNameResolverProvider.overrideWith(
          (ref) => ref.watch(composedResourceNameResolverProvider),
        ),
      ],
      child: DetailSubCard(
        key: const ValueKey('stack_recent_activity'),
        title: 'Recent activity',
        icon: AppIcons.history,
        collapsible: true,
        initiallyExpanded: false,
        summary: count == null
            ? 'Loading…'
            : count == 0
            ? 'No recent activity'
            : '$count recent update${count == 1 ? '' : 's'}',
        child: async.when(
          data: (state) {
            if (state.items.isEmpty) {
              return const Text('No recent activity for this stack.');
            }
            final shown = state.items.take(_visible).toList();
            final canShowMore = state.items.length > shown.length || hasMore;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final update in shown) ...[
                  UpdateTile(update: update),
                  const Gap(AppSpacing.sm),
                ],
                if (canShowMore && state.isLoadingMore)
                  const Center(child: AppInlineSkeleton(size: 20))
                else if (canShowMore)
                  TextButton(
                    onPressed: () {
                      setState(() => _visible += _pageSize);
                      if (state.items.length < _visible + _pageSize &&
                          hasMore) {
                        unawaited(
                          ref
                              .read(
                                stackUpdatesProvider(widget.stackId).notifier,
                              )
                              .fetchNextPage(),
                        );
                      }
                    },
                    child: const Text('Show more'),
                  ),
              ],
            );
          },
          loading: () => const AppSkeletonCard(showChips: false),
          error: (error, _) => Text('Failed to load updates: $error'),
        ),
      ),
    );
  }
}
