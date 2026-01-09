import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/variables/data/models/variable.dart';
import 'package:komodo_go/features/variables/data/repositories/variable_repository.dart';

part 'variables_provider.g.dart';

@riverpod
class Variables extends _$Variables {
  @override
  Future<List<KomodoVariable>> build() async {
    final repository = ref.watch(variableRepositoryProvider);
    if (repository == null) return [];

    final result = await repository.listVariables();
    return result.fold(
      (failure) => throw Exception(failure.displayMessage),
      (variables) => variables,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

@riverpod
class VariableActions extends _$VariableActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> create({
    required String name,
    required String value,
    required String description,
    required bool isSecret,
  }) async {
    return _execute(
      (repo) => repo.createVariable(
        name: name,
        value: value,
        description: description,
        isSecret: isSecret,
      ),
    );
  }

  Future<bool> delete(String name) async {
    return _execute((repo) => repo.deleteVariable(name: name));
  }

  Future<bool> update({
    required KomodoVariable original,
    required String value,
    required String description,
    required bool isSecret,
  }) async {
    final repository = ref.read(variableRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();

    if (description.trim() != original.description.trim()) {
      final result = await repository.updateVariableDescription(
        name: original.name,
        description: description.trim(),
      );
      final ok = result.fold(
        (failure) {
          state = AsyncValue.error(failure.displayMessage, StackTrace.current);
          return false;
        },
        (_) => true,
      );
      if (!ok) return false;
    }

    if (isSecret != original.isSecret) {
      final result = await repository.updateVariableIsSecret(
        name: original.name,
        isSecret: isSecret,
      );
      final ok = result.fold(
        (failure) {
          state = AsyncValue.error(failure.displayMessage, StackTrace.current);
          return false;
        },
        (_) => true,
      );
      if (!ok) return false;
    }

    if (value != original.value) {
      final result = await repository.updateVariableValue(
        name: original.name,
        value: value,
      );
      return result.fold(
        (failure) {
          state = AsyncValue.error(failure.displayMessage, StackTrace.current);
          return false;
        },
        (_) {
          state = const AsyncValue.data(null);
          ref.invalidate(variablesProvider);
          return true;
        },
      );
    }

    state = const AsyncValue.data(null);
    ref.invalidate(variablesProvider);
    return true;
  }

  Future<bool> _execute(
    Future<Either<Failure, KomodoVariable>> Function(VariableRepository repo)
    action,
  ) async {
    final repository = ref.read(variableRepositoryProvider);
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
        ref.invalidate(variablesProvider);
        return true;
      },
    );
  }
}
