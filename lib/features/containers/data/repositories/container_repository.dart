import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/utils/debug_log.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/data/models/container_log.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

  /// Stops a docker container on the target server.
  Future<Either<Failure, void>> stopContainer({
    required String serverIdOrName,
    required String containerIdOrName,
  }) async {
    return _executeAction(
      'StopContainer',
      {'server': serverIdOrName, 'container': containerIdOrName},
    );
  }

  /// Restarts a docker container on the target server.
  Future<Either<Failure, void>> restartContainer({
    required String serverIdOrName,
    required String containerIdOrName,
  }) async {
    return _executeAction(
      'RestartContainer',
      {'server': serverIdOrName, 'container': containerIdOrName},
    );
  }

  Future<Either<Failure, void>> _executeAction(
    String actionType,
    Map<String, dynamic> params,
  ) async {
    return apiCall(() async {
      await _client.execute(RpcRequest(type: actionType, params: params));
      return;
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
