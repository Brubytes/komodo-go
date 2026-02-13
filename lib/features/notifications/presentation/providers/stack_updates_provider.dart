import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/data/repositories/notifications_repository.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stack_updates_provider.g.dart';

@riverpod
class StackUpdates extends _$StackUpdates {
  @override
  Future<UpdatesState> build(String stackId) async {
    final repository = ref.watch(notificationsRepositoryProvider);
    if (repository == null || stackId.trim().isEmpty) {
      return const UpdatesState(items: <UpdateListItem>[], nextPage: null);
    }

    final result = await repository.listUpdates(
      page: 0,
      query: _stackUpdatesQuery(stackId),
    );
    final page = unwrapOrThrow(result);
    return UpdatesState(items: page.updates, nextPage: page.nextPage);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Ignore refresh errors.
    }
  }

  Future<void> fetchNextPage() async {
    final current = state.asData?.value;
    if (current == null) return;
    final nextPage = current.nextPage;
    if (nextPage == null) return;
    if (current.isLoadingMore) return;

    final repository = ref.read(notificationsRepositoryProvider);
    if (repository == null) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final result = await repository.listUpdates(
      page: nextPage,
      query: _stackUpdatesQuery(stackId),
    );

    state = result.fold(
      (_) => AsyncValue.data(current.copyWith(isLoadingMore: false)),
      (page) => AsyncValue.data(
        UpdatesState(
          items: [...current.items, ...page.updates],
          nextPage: page.nextPage,
        ),
      ),
    );
  }
}

Map<String, dynamic> _stackUpdatesQuery(String stackId) {
  return <String, dynamic>{
    'target': <String, dynamic>{
      'type': 'Stack',
      'id': stackId,
    },
  };
}
