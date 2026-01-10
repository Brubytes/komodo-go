import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/provider_error.dart';
import '../../data/models/sync.dart';
import '../../data/repositories/sync_repository.dart';

part 'syncs_provider.g.dart';

/// Provides the list of all syncs.
@riverpod
class Syncs extends _$Syncs {
  @override
  Future<List<ResourceSyncListItem>> build() async {
    final repository = ref.watch(syncRepositoryProvider);
    if (repository == null) {
      return [];
    }

    final result = await repository.listSyncs();

    return unwrapOrThrow(result);
  }

  /// Refreshes the syncs list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Provides details for a specific sync.
@riverpod
Future<KomodoResourceSync?> syncDetail(Ref ref, String syncIdOrName) async {
  final repository = ref.watch(syncRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getSync(syncIdOrName);

  return unwrapOrThrow(result);
}

/// Action state for sync operations.
@riverpod
class SyncActions extends _$SyncActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> run(String syncIdOrName) =>
      _executeAction((repo) => repo.runSync(syncIdOrName));

  Future<bool> _executeAction(
    Future<Either<Failure, void>> Function(SyncRepository repo) action,
  ) async {
    final repository = ref.read(syncRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();

    final result = await action(repository);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(syncsProvider);
        return true;
      },
    );
  }
}
