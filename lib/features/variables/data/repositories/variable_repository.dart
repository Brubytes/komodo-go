import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/variables/data/models/variable.dart';

part 'variable_repository.g.dart';

class VariableRepository {
  VariableRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, List<KomodoVariable>>> listVariables() async {
    return apiCall(() async {
      final response = await _client.read(
        const RpcRequest(type: 'ListVariables', params: <String, dynamic>{}),
      );

      final variablesJson = response as List<dynamic>? ?? [];
      return variablesJson
          .map((json) => KomodoVariable.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Either<Failure, KomodoVariable>> createVariable({
    required String name,
    required String value,
    required String description,
    required bool isSecret,
  }) async {
    return apiCall(() async {
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

      return KomodoVariable.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, KomodoVariable>> deleteVariable({
    required String name,
  }) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(type: 'DeleteVariable', params: <String, dynamic>{'name': name}),
      );

      return KomodoVariable.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, KomodoVariable>> updateVariableValue({
    required String name,
    required String value,
  }) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'UpdateVariableValue',
          params: <String, dynamic>{'name': name, 'value': value},
        ),
      );

      return KomodoVariable.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, KomodoVariable>> updateVariableDescription({
    required String name,
    required String description,
  }) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'UpdateVariableDescription',
          params: <String, dynamic>{'name': name, 'description': description},
        ),
      );

      return KomodoVariable.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, KomodoVariable>> updateVariableIsSecret({
    required String name,
    required bool isSecret,
  }) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'UpdateVariableIsSecret',
          params: <String, dynamic>{'name': name, 'is_secret': isSecret},
        ),
      );

      return KomodoVariable.fromJson(response as Map<String, dynamic>);
    });
  }
}

@riverpod
VariableRepository? variableRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return VariableRepository(client);
}
