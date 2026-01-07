import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/data/repositories/notifications_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'updates_provider.g.dart';

class UpdatesState {
  const UpdatesState({
    required this.items,
    required this.nextPage,
    this.isLoadingMore = false,
  });

  final List<UpdateListItem> items;
  final int? nextPage;
  final bool isLoadingMore;

  UpdatesState copyWith({
    List<UpdateListItem>? items,
    int? nextPage,
    bool? isLoadingMore,
  }) {
    return UpdatesState(
      items: items ?? this.items,
      nextPage: nextPage ?? this.nextPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@riverpod
class Updates extends _$Updates {
  @override
  Future<UpdatesState> build() async {
    final repository = ref.watch(notificationsRepositoryProvider);
    if (repository == null) {
      return const UpdatesState(items: <UpdateListItem>[], nextPage: null);
    }

    final result = await repository.listUpdates(page: 0);
    return result.fold(
      (failure) => throw Exception(failure.displayMessage),
      (page) => UpdatesState(items: page.updates, nextPage: page.nextPage),
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
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

    final result = await repository.listUpdates(page: nextPage);
    state = result.fold(
      (_) {
        return AsyncValue.data(current.copyWith(isLoadingMore: false));
      },
      (page) {
        return AsyncValue.data(
          UpdatesState(
            items: [...current.items, ...page.updates],
            nextPage: page.nextPage,
            isLoadingMore: false,
          ),
        );
      },
    );
  }
}
