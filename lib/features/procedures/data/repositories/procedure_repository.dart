import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/dio_provider.dart';
import '../models/procedure.dart';

part 'procedure_repository.g.dart';

/// Repository for procedure-related operations.
class ProcedureRepository {
  ProcedureRepository(this._client);

  final KomodoApiClient _client;

  static const Map<String, dynamic> _emptyProcedureQuery = <String, dynamic>{
    'names': <String>[],
    'templates': 'Include',
    'tags': <String>[],
    'tag_behavior': 'All',
    'specific': <String, dynamic>{},
  };

  /// Lists all procedures.
  Future<Either<Failure, List<ProcedureListItem>>> listProcedures() async {
    try {
      final response = await _client.read(
        const RpcRequest(
          type: 'ListProcedures',
          params: <String, dynamic>{'query': _emptyProcedureQuery},
        ),
      );

      final proceduresJson = response as List<dynamic>? ?? [];
      final procedures = proceduresJson
          .map(
            (json) => ProcedureListItem.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      return Right(procedures);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('Error parsing procedures: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Gets a specific procedure by ID or name.
  Future<Either<Failure, KomodoProcedure>> getProcedure(
    String procedureIdOrName,
  ) async {
    try {
      final response = await _client.read(
        RpcRequest(
          type: 'GetProcedure',
          params: {'procedure': procedureIdOrName},
        ),
      );

      return Right(KomodoProcedure.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      if (e.isNotFound) {
        return const Left(Failure.server(message: 'Procedure not found'));
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Runs the target procedure.
  Future<Either<Failure, void>> runProcedure(String procedureIdOrName) async {
    try {
      await _client.execute(
        RpcRequest(type: 'RunProcedure', params: {'procedure': procedureIdOrName}),
      );
      return const Right(null);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
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

