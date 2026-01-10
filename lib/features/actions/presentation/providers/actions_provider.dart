import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'actions_provider.g.dart';

/// Provides the list of all actions.
@riverpod
class Actions extends _$Actions {
  @override
  Future<List<ActionListItem>> build() async {
    final repository = ref.watch(actionRepositoryProvider);
    if (repository == null) {
      return [];
    }

    final result = await repository.listActions();

    return unwrapOrThrow(result);
  }

  /// Refreshes the actions list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Provides details for a specific action.
@riverpod
Future<KomodoAction?> actionDetail(Ref ref, String actionIdOrName) async {
  final repository = ref.watch(actionRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getAction(actionIdOrName);

  return unwrapOrThrow(result);
}

/// Action state for action operations.
@riverpod
class ActionActions extends _$ActionActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> run(String actionIdOrName, {Map<String, dynamic>? args}) =>
      _executeAction((repo) => repo.runAction(actionIdOrName, args: args));

  Future<bool> _executeAction(
    Future<Either<Failure, void>> Function(ActionRepository repo) action,
  ) async {
    final repository = ref.read(actionRepositoryProvider);
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
        ref.invalidate(actionsProvider);
        return true;
      },
    );
  }
}
