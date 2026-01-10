import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/provider_error.dart';
import '../../data/models/procedure.dart';
import '../../data/repositories/procedure_repository.dart';

part 'procedures_provider.g.dart';

/// Provides the list of all procedures.
@riverpod
class Procedures extends _$Procedures {
  @override
  Future<List<ProcedureListItem>> build() async {
    final repository = ref.watch(procedureRepositoryProvider);
    if (repository == null) {
      return [];
    }

    final result = await repository.listProcedures();

    return unwrapOrThrow(result);
  }

  /// Refreshes the procedures list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Provides details for a specific procedure.
@riverpod
Future<KomodoProcedure?> procedureDetail(Ref ref, String procedureIdOrName) async {
  final repository = ref.watch(procedureRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getProcedure(procedureIdOrName);

  return unwrapOrThrow(result);
}

/// Action state for procedure operations.
@riverpod
class ProcedureActions extends _$ProcedureActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> run(String procedureIdOrName) =>
      _executeAction((repo) => repo.runProcedure(procedureIdOrName));

  Future<bool> _executeAction(
    Future<Either<Failure, void>> Function(ProcedureRepository repo) action,
  ) async {
    final repository = ref.read(procedureRepositoryProvider);
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
        ref.invalidate(proceduresProvider);
        return true;
      },
    );
  }
}
