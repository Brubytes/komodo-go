import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/paginated_read.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/utils/debug_log.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'procedure_repository.g.dart';

/// Repository for procedure-related operations.
class ProcedureRepository {
  ProcedureRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all procedures.
  Future<Either<Failure, List<ProcedureListItem>>> listProcedures([
    ResourceListOptions options = const ResourceListOptions(),
  ]) async {
    return apiCall(
      () async {
        final proceduresJson = await readAllPages(
          _client,
          type: 'ListProcedures',
          params: options.params(),
          pageSize: options.pageSize,
        );
        return proceduresJson
            .map(
              (json) =>
                  ProcedureListItem.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      },
      onUnknown: (error) {
        debugLog('Error parsing procedures', name: 'API', error: error);
        return Failure.unknown(message: error.toString());
      },
    );
  }

  /// Gets a specific procedure by ID or name.
  Future<Either<Failure, KomodoProcedure>> getProcedure(
    String procedureIdOrName,
  ) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'GetProcedure',
            params: {'procedure': procedureIdOrName},
          ),
        );

        return KomodoProcedure.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Procedure not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }

  /// Runs the target procedure.
  Future<Either<Failure, void>> runProcedure(String procedureIdOrName) async {
    return apiCall(
      () async {
        await _client.execute(
          RpcRequest(
            type: 'RunProcedure',
            params: {'procedure': procedureIdOrName},
          ),
        );
        return;
      },
    );
  }

  /// Cancels the currently running update for the target procedure.
  Future<Either<Failure, void>> cancelProcedure(
    String procedureIdOrName, {
    String? updateId,
  }) async {
    if (!_client.capabilities.supportsActionCancellation) {
      return const Left(
        Failure.server(
          message: 'Canceling procedures requires Komodo 2.3 or newer.',
        ),
      );
    }
    return apiCall(() async {
      await _client.execute(
        RpcRequest(
          type: 'CancelProcedure',
          params: <String, dynamic>{
            'procedure': procedureIdOrName,
            'update_id': ?updateId,
          },
        ),
      );
      return;
    });
  }

  /// Updates a procedure configuration and returns the updated procedure.
  ///
  /// Uses the `/write` module `UpdateProcedure` RPC.
  ///
  /// Note: Only fields included in [partialConfig] will be updated.
  Future<Either<Failure, KomodoProcedure>> updateProcedureConfig({
    required String procedureId,
    required Map<String, dynamic> partialConfig,
  }) async {
    return apiCall(
      () async {
        final response = await _client.write(
          RpcRequest(
            type: 'UpdateProcedure',
            params: <String, dynamic>{
              'id': procedureId,
              'config': partialConfig,
            },
          ),
        );

        return KomodoProcedure.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Procedure not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }
}

@riverpod
ProcedureRepository? procedureRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return ProcedureRepository(client);
}
