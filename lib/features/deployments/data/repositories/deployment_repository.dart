import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/paginated_read.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/utils/debug_log.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/shared/logs/server_log.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deployment_repository.g.dart';

/// Repository for deployment-related operations.
class DeploymentRepository {
  DeploymentRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all deployments.
  Future<Either<Failure, List<Deployment>>> listDeployments([
    ResourceListOptions options = const ResourceListOptions(),
  ]) async {
    return apiCall(
      () async {
        final deploymentsJson = await readAllPages(
          _client,
          type: 'ListDeployments',
          params: options.params(
            specific: <String, dynamic>{
              'server_ids': <String>[],
              'build_ids': <String>[],
              'update_available': false,
            },
          ),
          pageSize: options.pageSize,
        );
        return deploymentsJson
            .map((json) => Deployment.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      onUnknown: (error) {
        debugLog('Error parsing deployments', name: 'API', error: error);
        return Failure.unknown(message: error.toString());
      },
    );
  }

  /// Lists deployments whose last image check found a newer image.
  Future<Either<Failure, List<Deployment>>> listUpdateCandidates() async {
    return apiCall(() async {
      final deploymentsJson = await readAllPages(
        _client,
        type: 'ListDeployments',
        params: const ResourceListOptions().params(
          specific: <String, dynamic>{
            'server_ids': <String>[],
            'build_ids': <String>[],
            'update_available': true,
          },
        ),
      );
      return deploymentsJson
          .map((json) => Deployment.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  /// Gets a specific deployment by ID or name.
  Future<Either<Failure, Deployment>> getDeployment(
    String deploymentIdOrName,
  ) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'GetDeployment',
            params: {'deployment': deploymentIdOrName},
          ),
        );

        return Deployment.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Deployment not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }

  /// Updates a deployment configuration and returns the updated deployment.
  ///
  /// Uses the `/write` module `UpdateDeployment` RPC.
  ///
  /// Note: Only fields included in [partialConfig] will be updated.
  Future<Either<Failure, Deployment>> updateDeploymentConfig({
    required String deploymentId,
    required Map<String, dynamic> partialConfig,
  }) async {
    return apiCall(
      () async {
        final response = await _client.write(
          RpcRequest(
            type: 'UpdateDeployment',
            params: <String, dynamic>{
              'id': deploymentId,
              'config': partialConfig,
            },
          ),
        );

        return Deployment.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Deployment not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }

  /// Starts a deployment.
  Future<Either<Failure, void>> startDeployment(
    String deploymentIdOrName,
  ) async {
    return _executeAction('StartDeployment', deploymentIdOrName);
  }

  /// Stops a deployment.
  Future<Either<Failure, void>> stopDeployment(
    String deploymentIdOrName,
  ) async {
    return _executeAction('StopDeployment', deploymentIdOrName);
  }

  /// Restarts a deployment.
  Future<Either<Failure, void>> restartDeployment(
    String deploymentIdOrName,
  ) async {
    return _executeAction('RestartDeployment', deploymentIdOrName);
  }

  /// Destroys a deployment (stops and removes the container).
  Future<Either<Failure, void>> destroyDeployment(
    String deploymentIdOrName,
  ) async {
    return _executeAction('DestroyDeployment', deploymentIdOrName);
  }

  /// Pauses a deployment.
  Future<Either<Failure, void>> pauseDeployment(
    String deploymentIdOrName,
  ) async {
    return _executeAction('PauseDeployment', deploymentIdOrName);
  }

  /// Unpauses a deployment.
  Future<Either<Failure, void>> unpauseDeployment(
    String deploymentIdOrName,
  ) async {
    return _executeAction('UnpauseDeployment', deploymentIdOrName);
  }

  /// Deploys (creates/updates) the container.
  Future<Either<Failure, void>> deploy(String deploymentIdOrName) async {
    return _executeAction('Deploy', deploymentIdOrName);
  }

  /// Pulls the image for the deployment.
  Future<Either<Failure, void>> pullDeployment(
    String deploymentIdOrName,
  ) async {
    return _executeAction('PullDeployment', deploymentIdOrName);
  }

  /// Checks the deployed image digest without triggering configured auto-update.
  Future<Either<Failure, bool>> checkForUpdate(
    String deploymentIdOrName,
  ) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'CheckDeploymentForUpdate',
          params: <String, dynamic>{
            'deployment': deploymentIdOrName,
            'skip_auto_update': true,
            'wait_for_auto_update': false,
          },
        ),
      );
      final json = response as Map<String, dynamic>;
      return json['update_available'] == true;
    });
  }

  Future<Either<Failure, ServerLogSnapshot>> loadServerLog({
    required String deploymentIdOrName,
    int tail = 200,
    bool timestamps = true,
  }) {
    return apiCall(() async {
      final response = await _client.read(
        RpcRequest(
          type: 'GetDeploymentLog',
          params: <String, dynamic>{
            'deployment': deploymentIdOrName,
            'tail': tail,
            'timestamps': timestamps,
          },
        ),
      );
      return ServerLogSnapshot.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, ServerLogSnapshot>> searchServerLog({
    required String deploymentIdOrName,
    required List<String> terms,
    required LogSearchCombinator combinator,
    bool invert = false,
    bool timestamps = true,
  }) {
    return apiCall(() async {
      final response = await _client.read(
        RpcRequest(
          type: 'SearchDeploymentLog',
          params: <String, dynamic>{
            'deployment': deploymentIdOrName,
            'terms': terms,
            'combinator': combinator.apiValue,
            'invert': invert,
            'timestamps': timestamps,
          },
        ),
      );
      return ServerLogSnapshot.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, void>> _executeAction(
    String actionType,
    String deploymentIdOrName,
  ) async {
    return apiCall(() async {
      await _client.execute(
        RpcRequest(
          type: actionType,
          params: {'deployment': deploymentIdOrName},
        ),
      );
      return;
    });
  }
}

@riverpod
DeploymentRepository? deploymentRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return DeploymentRepository(client);
}
