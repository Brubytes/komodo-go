import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
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

  static const Map<String, dynamic> _emptyDeploymentQuery = <String, dynamic>{
    'names': <String>[],
    'templates': 'Include',
    'tags': <String>[],
    'tag_behavior': 'All',
    'specific': <String, dynamic>{
      'server_ids': <String>[],
      'build_ids': <String>[],
      'update_available': false,
    },
  };

  /// Lists all deployments.
  Future<Either<Failure, List<Deployment>>> listDeployments() async {
    try {
      final response = await _client.read(
        const RpcRequest(
          type: 'ListDeployments',
          params: <String, dynamic>{'query': _emptyDeploymentQuery},
        ),
      );

      // API returns array directly for list endpoints
      final deploymentsJson = response as List<dynamic>? ?? [];
      final deployments = deploymentsJson
          .map((json) => Deployment.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(deployments);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e, stackTrace) {
      debugLog(
        'Error parsing deployments',
        name: 'API',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Gets a specific deployment by ID or name.
  Future<Either<Failure, Deployment>> getDeployment(
    String deploymentIdOrName,
  ) async {
    try {
      final response = await _client.read(
        RpcRequest(
          type: 'GetDeployment',
          params: {'deployment': deploymentIdOrName},
        ),
      );

      return Right(Deployment.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      if (e.isNotFound) {
        return const Left(Failure.server(message: 'Deployment not found'));
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
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
    try {
      await _client.execute(
        RpcRequest(
          type: actionType,
          params: {'deployment': deploymentIdOrName},
        ),
      );
      return const Right(null);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
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
