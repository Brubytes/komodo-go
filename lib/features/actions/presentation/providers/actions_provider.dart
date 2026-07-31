import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';
import 'package:komodo_go/shared/resources/providers/resource_action_executor.dart';
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
    try {
      await future;
    } on Exception {
      // Ignore refresh errors.
    }
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
class ActionActions extends _$ActionActions
    with ResourceActionExecutor<ActionRepository> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  ActionRepository? readRepository() => ref.read(actionRepositoryProvider);

  @override
  void invalidateList() => ref.invalidate(actionsProvider);

  @override
  bool get isMounted => ref.mounted;

  Future<bool> run(String actionIdOrName, {Map<String, dynamic>? args}) =>
      executeAction((repo) => repo.runAction(actionIdOrName, args: args));

  Future<bool> cancel(String actionIdOrName, {String? updateId}) =>
      executeAction(
        (repo) => repo.cancelAction(actionIdOrName, updateId: updateId),
      );

  Future<KomodoAction?> updateActionConfig({
    required String actionId,
    required Map<String, dynamic> partialConfig,
  }) => executeRequest(
    (repo) => repo.updateActionConfig(
      actionId: actionId,
      partialConfig: partialConfig,
    ),
  );
}
