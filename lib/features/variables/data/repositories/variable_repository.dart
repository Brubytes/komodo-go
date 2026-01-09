import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/variables/data/models/variable.dart';

part 'variable_repository.g.dart';

class VariableRepository {
  VariableRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, List<KomodoVariable>>> listVariables() async {
    try {
      final response = await _client.read(
        const RpcRequest(type: 'ListVariables', params: <String, dynamic>{}),
      );

      final variablesJson = response as List<dynamic>? ?? [];
      final variables = variablesJson
          .map((json) => KomodoVariable.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(variables);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, KomodoVariable>> createVariable({
    required String name,
    required String value,
    required String description,
    required bool isSecret,
  }) async {
    try {
      final response = await _client.write(
        RpcRequest(
          type: 'CreateVariable',
          params: <String, dynamic>{
            'name': name,
            'value': value,
            'description': description,
            'is_secret': isSecret,
          },
        ),
      );

      return Right(KomodoVariable.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, KomodoVariable>> deleteVariable({
    required String name,
  }) async {
    try {
      final response = await _client.write(
        RpcRequest(type: 'DeleteVariable', params: <String, dynamic>{'name': name}),
      );

      return Right(KomodoVariable.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, KomodoVariable>> updateVariableValue({
    required String name,
    required String value,
  }) async {
    try {
      final response = await _client.write(
        RpcRequest(
          type: 'UpdateVariableValue',
          params: <String, dynamic>{'name': name, 'value': value},
        ),
      );

      return Right(KomodoVariable.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, KomodoVariable>> updateVariableDescription({
    required String name,
    required String description,
  }) async {
    try {
      final response = await _client.write(
        RpcRequest(
          type: 'UpdateVariableDescription',
          params: <String, dynamic>{'name': name, 'description': description},
        ),
      );

      return Right(KomodoVariable.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, KomodoVariable>> updateVariableIsSecret({
    required String name,
    required bool isSecret,
  }) async {
    try {
      final response = await _client.write(
        RpcRequest(
          type: 'UpdateVariableIsSecret',
          params: <String, dynamic>{'name': name, 'is_secret': isSecret},
        ),
      );

      return Right(KomodoVariable.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}

@riverpod
VariableRepository? variableRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return VariableRepository(client);
}

