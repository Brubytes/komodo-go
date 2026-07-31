import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Shared `_executeAction`/`_executeRequest` logic for resource action states.
///
/// Hosts provide repository access, list invalidation, and mount state.
mixin ResourceActionExecutor<RepoT> {
  AsyncValue<void> get state;

  set state(AsyncValue<void> value);

  RepoT? readRepository();

  void invalidateList();

  bool get isMounted;

  Future<bool> executeAction(
    Future<Either<Failure, void>> Function(RepoT repo) action,
  ) async {
    final repository = readRepository();
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();

    final result = await action(repository);

    if (!isMounted) return false;

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        invalidateList();
        return true;
      },
    );
  }

  Future<T?> executeRequest<T>(
    Future<Either<Failure, T>> Function(RepoT repo) request,
  ) async {
    final repository = readRepository();
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();

    final result = await request(repository);

    if (!isMounted) return null;

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return null;
      },
      (value) {
        state = const AsyncValue.data(null);
        invalidateList();
        return value;
      },
    );
  }
}
