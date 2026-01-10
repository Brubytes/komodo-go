import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_call.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/utils/debug_log.dart';
import '../models/container.dart';
import '../models/container_log.dart';

part 'container_repository.g.dart';

/// Repository for docker container related operations.
class ContainerRepository {
  ContainerRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all docker containers on the target server.
  Future<Either<Failure, List<ContainerListItem>>> listDockerContainers(
    String serverIdOrName,
  ) async {
    return apiCall(() async {
      try {
        final response = await _client.read(
          RpcRequest(
            type: 'ListDockerContainers',
            params: {'server': serverIdOrName},
          ),
        );

        final itemsJson = response as List<dynamic>? ?? [];
        return itemsJson
            .map(
              (json) => ContainerListItem.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } catch (e, stackTrace) {
        if (e is ApiException) rethrow;
        debugLog(
          'Error parsing containers',
          name: 'API',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    });
  }

  Future<Either<Failure, ContainerLog>> getContainerLog({
    required String serverIdOrName,
    required String containerIdOrName,
    int tail = 200,
    bool timestamps = false,
  }) async {
    return apiCall(() async {
      final response = await _client.read(
        RpcRequest(
          type: 'GetContainerLog',
          params: {
            'server': serverIdOrName,
            'container': containerIdOrName,
            'tail': tail,
            'timestamps': timestamps,
          },
        ),
      );

      return ContainerLog.fromJson(response as Map<String, dynamic>);
    });
  }
}

@riverpod
ContainerRepository? containerRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return ContainerRepository(client);
}
