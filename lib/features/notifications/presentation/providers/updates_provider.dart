import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/core/network/refresh_in_place.dart';
import 'package:komodo_go/features/notifications/data/models/update_detail.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/data/repositories/notifications_repository.dart';
import 'package:komodo_go/shared/resources/providers/resource_activity_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'updates_provider.g.dart';

class UpdatesState {
  const UpdatesState({
    required this.items,
    required this.nextPage,
    this.isLoadingMore = false,
    this.loadedPages = 1,
  });

  final List<UpdateListItem> items;
  final int? nextPage;
  final bool isLoadingMore;

  /// Number of pages merged into [items] (1 after the first page).
  final int loadedPages;

  UpdatesState copyWith({
    List<UpdateListItem>? items,
    int? nextPage,
    bool? isLoadingMore,
    int? loadedPages,
  }) {
    return UpdatesState(
      items: items ?? this.items,
      nextPage: nextPage ?? this.nextPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadedPages: loadedPages ?? this.loadedPages,
    );
  }
}

/// Appends [incoming] to [existing], dropping items whose id is already
/// present (first occurrence wins). Used by paginated providers so a page 0
/// merge followed by load-more never shows a row twice.
List<T> appendDedupedById<T>(
  List<T> existing,
  List<T> incoming,
  String Function(T item) idOf,
) {
  final seen = <String>{};
  final result = <T>[];
  for (final item in [...existing, ...incoming]) {
    if (seen.add(idOf(item))) result.add(item);
  }
  return result;
}

@riverpod
class Updates extends _$Updates {
  @override
  Future<UpdatesState> build() async {
    // Activity pulses merge a fresh first page in place (see _onActivity)
    // instead of rebuilding, so loaded pagination is never discarded.
    ref.listen<int>(resourceAnyActivityProvider, (_, _) => _onActivity());
    final repository = ref.watch(notificationsRepositoryProvider);
    if (repository == null) {
      return const UpdatesState(items: <UpdateListItem>[], nextPage: null);
    }

    final result = await repository.listUpdates(page: 0);
    final page = unwrapOrThrow(result);
    return UpdatesState(items: page.updates, nextPage: page.nextPage);
  }

  /// Re-fetches page 0 and merges it into the loaded pages: fresh items first,
  /// then previously loaded items that are not on page 0. Loaded older pages
  /// and the pagination cursor are kept. State changes only if something did.
  Future<void> _onActivity() async {
    final current = state.value;
    final repository = ref.read(notificationsRepositoryProvider);
    if (current == null || repository == null) return;
    if (state.isLoading || current.isLoadingMore) return;
    await refreshInPlace<UpdatesState>(
      current: current,
      fetch: () async {
        final page = unwrapOrThrow(await repository.listUpdates(page: 0));
        final freshIds = {for (final item in page.updates) item.id};
        final loadedMore = current.loadedPages > 1;
        return UpdatesState(
          items: appendDedupedById(
            page.updates,
            current.items.where((i) => !freshIds.contains(i.id)).toList(),
            (i) => i.id,
          ),
          // Keep the cursor once older pages were loaded.
          nextPage: loadedMore ? current.nextPage : page.nextPage,
          loadedPages: current.loadedPages,
        );
      },
      apply: (value) {
        // A refresh in flight or a load-more that raced with this fetch owns
        // the state; drop ours.
        if (state.isLoading || !identical(state.value, current)) return;
        state = AsyncData(value);
      },
      equals: _sameUpdates,
      isMounted: () => ref.mounted,
    );
  }

  static bool _sameUpdates(UpdatesState a, UpdatesState b) {
    if (a.nextPage != b.nextPage || a.items.length != b.items.length) {
      return false;
    }
    for (var i = 0; i < a.items.length; i++) {
      final x = a.items[i];
      final y = b.items[i];
      if (x.id != y.id || x.status != y.status || x.success != y.success) {
        return false;
      }
    }
    return true;
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
    final current = state.value;
    if (current == null) return;
    final nextPage = current.nextPage;
    if (nextPage == null) return;
    if (current.isLoadingMore) return;

    final repository = ref.read(notificationsRepositoryProvider);
    if (repository == null) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final result = await repository.listUpdates(page: nextPage);
    if (!ref.mounted) return;
    state = result.fold(
      (_) {
        return AsyncValue.data(current.copyWith(isLoadingMore: false));
      },
      (page) {
        return AsyncValue.data(
          UpdatesState(
            items: appendDedupedById(
              current.items,
              page.updates,
              (i) => i.id,
            ),
            nextPage: page.nextPage,
            loadedPages: current.loadedPages + 1,
          ),
        );
      },
    );
  }
}

@riverpod
Future<UpdateDetail?> updateDetail(Ref ref, String id) async {
  final repository = ref.watch(notificationsRepositoryProvider);
  if (repository == null || id.trim().isEmpty) return null;
  final result = await repository.getUpdate(id);
  return unwrapOrThrow(result);
}
