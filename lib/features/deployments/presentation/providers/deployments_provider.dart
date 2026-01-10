import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deployments_provider.g.dart';

/// Provides the list of all deployments.
@riverpod
class Deployments extends _$Deployments {
  @override
  Future<List<Deployment>> build() async {
    final repository = ref.watch(deploymentRepositoryProvider);

    // Not authenticated yet - return empty list and wait for auth
    if (repository == null) {
      return [];
    }

    final result = await repository.listDeployments();

    return unwrapOrThrow(result);
  }

  /// Refreshes the deployment list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {}
  }
}

/// Provides details for a specific deployment.
@riverpod
Future<Deployment?> deploymentDetail(Ref ref, String deploymentId) async {
  final repository = ref.watch(deploymentRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getDeployment(deploymentId);

  return unwrapOrThrow(result);
}

/// Action state for deployment operations.
@riverpod
class DeploymentActions extends _$DeploymentActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> start(String deploymentId) =>
      _executeAction((repo) => repo.startDeployment(deploymentId));

  Future<bool> stop(String deploymentId) =>
      _executeAction((repo) => repo.stopDeployment(deploymentId));

  Future<bool> restart(String deploymentId) =>
      _executeAction((repo) => repo.restartDeployment(deploymentId));

  Future<bool> destroy(String deploymentId) =>
      _executeAction((repo) => repo.destroyDeployment(deploymentId));

  Future<bool> deploy(String deploymentId) =>
      _executeAction((repo) => repo.deploy(deploymentId));

  Future<bool> pullImages(String deploymentId) =>
      _executeAction((repo) => repo.pullDeployment(deploymentId));

  Future<bool> pause(String deploymentId) =>
      _executeAction((repo) => repo.pauseDeployment(deploymentId));

  Future<bool> unpause(String deploymentId) =>
      _executeAction((repo) => repo.unpauseDeployment(deploymentId));

  Future<bool> _executeAction(
    Future<Either<Failure, void>> Function(DeploymentRepository repo) action,
  ) async {
    final repository = ref.read(deploymentRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();

    final result = await action(repository);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(deploymentsProvider);
        return true;
      },
    );
  }
}
