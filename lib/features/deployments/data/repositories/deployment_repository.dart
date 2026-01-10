import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/query_templates.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/utils/debug_log.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deployment_repository.g.dart';

/// Repository for deployment-related operations.
class DeploymentRepository {
  DeploymentRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all deployments.
  Future<Either<Failure, List<Deployment>>> listDeployments() async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'ListDeployments',
            params: <String, dynamic>{
              'query': emptyQuery(
                specific: <String, dynamic>{
                  'server_ids': <String>[],
                  'build_ids': <String>[],
                  'update_available': false,
                },
              ),
            },
          ),
        );

        // API returns array directly for list endpoints
        final deploymentsJson = response as List<dynamic>? ?? [];
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
      return null;
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
