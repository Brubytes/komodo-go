import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/data/repositories/procedure_repository.dart';
import 'package:komodo_go/shared/resources/providers/resource_action_executor.dart';
import 'package:komodo_go/shared/resources/providers/resource_activity_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'procedures_provider.g.dart';

/// Provides the list of all procedures.
@riverpod
class Procedures extends _$Procedures {
  @override
  Future<List<ProcedureListItem>> build() async {
    ref.watch(resourceActivityProvider);
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
    try {
      await future;
    } on Exception {
      // Ignore refresh errors.
    }
  }
}

/// Provides details for a specific procedure.
@riverpod
Future<KomodoProcedure?> procedureDetail(
  Ref ref,
  String procedureIdOrName,
) async {
  ref.watch(resourceActivityProvider);
  final repository = ref.watch(procedureRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getProcedure(procedureIdOrName);

  return unwrapOrThrow(result);
}

/// Action state for procedure operations.
@riverpod
class ProcedureActions extends _$ProcedureActions
    with ResourceActionExecutor<ProcedureRepository> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  ProcedureRepository? readRepository() =>
      ref.read(procedureRepositoryProvider);

  @override
  void invalidateList() => ref.invalidate(proceduresProvider);

  @override
  void markResourceActivity() => ref.markResourceActivity();

  @override
  bool get isMounted => ref.mounted;

  Future<bool> run(String procedureIdOrName) =>
      executeAction((repo) => repo.runProcedure(procedureIdOrName));

  Future<bool> cancel(String procedureIdOrName, {String? updateId}) =>
      executeAction(
        (repo) => repo.cancelProcedure(procedureIdOrName, updateId: updateId),
      );

  Future<KomodoProcedure?> updateProcedureConfig({
    required String procedureId,
    required Map<String, dynamic> partialConfig,
  }) => executeRequest(
    (repo) => repo.updateProcedureConfig(
      procedureId: procedureId,
      partialConfig: partialConfig,
    ),
  );
}
