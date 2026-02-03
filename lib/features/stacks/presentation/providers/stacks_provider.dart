import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stacks_provider.g.dart';

/// Provides the list of all stacks.
@riverpod
class Stacks extends _$Stacks {
  @override
  Future<List<StackListItem>> build() async {
    final repository = ref.watch(stackRepositoryProvider);
    if (repository == null) {
      return [];
    }

    final result = await repository.listStacks();

    return unwrapOrThrow(result);
  }

  /// Refreshes the stacks list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Ignore refresh errors.
    }
  }
}

/// Provides details for a specific stack.
@riverpod
Future<KomodoStack?> stackDetail(Ref ref, String stackIdOrName) async {
  final repository = ref.watch(stackRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getStack(stackIdOrName);

  return unwrapOrThrow(result);
}

/// Provides services (containers) for a specific stack.
@riverpod
Future<List<StackService>> stackServices(Ref ref, String stackIdOrName) async {
  final repository = ref.watch(stackRepositoryProvider);
  if (repository == null) {
    return [];
  }

  final result = await repository.listStackServices(stackIdOrName);

  return unwrapOrThrow(result);
}

/// Provides a recent log snapshot for a stack.
@riverpod
Future<StackLog?> stackLog(Ref ref, String stackIdOrName) async {
  final repository = ref.watch(stackRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getStackLog(stackIdOrName: stackIdOrName);

  return unwrapOrThrow(result);
}

/// Action state for stack operations.
@riverpod
class StackActions extends _$StackActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> deploy(String stackIdOrName) =>
      _executeAction((repo) => repo.deployStack(stackIdOrName));

  Future<bool> pullImages(String stackIdOrName) =>
      _executeAction((repo) => repo.pullStackImages(stackIdOrName));

  Future<bool> restart(String stackIdOrName) =>
      _executeAction((repo) => repo.restartStack(stackIdOrName));

  Future<bool> pause(String stackIdOrName) =>
      _executeAction((repo) => repo.pauseStack(stackIdOrName));

  Future<bool> start(String stackIdOrName) =>
      _executeAction((repo) => repo.startStack(stackIdOrName));

  Future<bool> stop(String stackIdOrName) =>
      _executeAction((repo) => repo.stopStack(stackIdOrName));

  Future<bool> destroy(String stackIdOrName) =>
      _executeAction((repo) => repo.destroyStack(stackIdOrName));

  Future<bool> writeStackFileContents({
    required String stackIdOrName,
    required String filePath,
    required String contents,
  }) => _executeAction(
    (repo) => repo.writeStackFileContents(
      stackIdOrName: stackIdOrName,
      filePath: filePath,
      contents: contents,
    ),
  );

  Future<KomodoStack?> updateStackConfig({
    required String stackId,
    required Map<String, dynamic> partialConfig,
  }) => _executeRequest(
    (repo) => repo.updateStackConfig(
      stackId: stackId,
      partialConfig: partialConfig,
    ),
  );

  Future<bool> _executeAction(
    Future<Either<Failure, void>> Function(StackRepository repo) action,
  ) async {
    final repository = ref.read(stackRepositoryProvider);
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
        ref.invalidate(stacksProvider);
        return true;
      },
    );
  }

  Future<T?> _executeRequest<T>(
    Future<Either<Failure, T>> Function(StackRepository repo) request,
  ) async {
    final repository = ref.read(stackRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();

    final result = await request(repository);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return null;
      },
      (value) {
        state = const AsyncValue.data(null);
        ref.invalidate(stacksProvider);
        return value;
      },
    );
  }
}
