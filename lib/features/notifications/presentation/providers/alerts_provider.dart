import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/repositories/notifications_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'alerts_provider.g.dart';

class AlertsState {
  const AlertsState({
    required this.items,
    required this.nextPage,
    this.isLoadingMore = false,
  });

  final List<Alert> items;
  final int? nextPage;
  final bool isLoadingMore;

  AlertsState copyWith({
    List<Alert>? items,
    int? nextPage,
    bool? isLoadingMore,
  }) {
    return AlertsState(
      items: items ?? this.items,
      nextPage: nextPage ?? this.nextPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@riverpod
class Alerts extends _$Alerts {
  @override
  Future<AlertsState> build() async {
    final repository = ref.watch(notificationsRepositoryProvider);
    if (repository == null) {
      return const AlertsState(items: <Alert>[], nextPage: null);
    }

    final result = await repository.listAlerts(page: 0);
    final page = unwrapOrThrow(result);
    return AlertsState(items: page.alerts, nextPage: page.nextPage);
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

    final result = await repository.listAlerts(page: nextPage);
    state = result.fold(
      (_) {
        return AsyncValue.data(current.copyWith(isLoadingMore: false));
      },
      (page) {
        return AsyncValue.data(
          AlertsState(
            items: [...current.items, ...page.alerts],
            nextPage: page.nextPage,
            isLoadingMore: false,
          ),
        );
      },
    );
  }
}
