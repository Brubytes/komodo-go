import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/deployment.dart';
import '../../data/repositories/deployment_repository.dart';

part 'deployments_provider.g.dart';

/// Provides the list of all deployments.
@riverpod
class Deployments extends _$Deployments {
  @override
  Future<List<Deployment>> build() async {
    final repository = ref.watch(deploymentRepositoryProvider);
    final result = await repository.listDeployments();

    return result.fold(
      (failure) => throw Exception(failure.displayMessage),
      (deployments) => deployments,
    );
  }

  /// Refreshes the deployment list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Provides details for a specific deployment.
@riverpod
Future<Deployment> deploymentDetail(Ref ref, String deploymentId) async {
  final repository = ref.watch(deploymentRepositoryProvider);
  final result = await repository.getDeployment(deploymentId);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (deployment) => deployment,
  );
}

/// Action state for deployment operations.
@riverpod
class DeploymentActions extends _$DeploymentActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> start(String deploymentId) => _executeAction(
        () => ref.read(deploymentRepositoryProvider).startDeployment(
              deploymentId,
            ),
      );

  Future<bool> stop(String deploymentId) => _executeAction(
        () => ref.read(deploymentRepositoryProvider).stopDeployment(
              deploymentId,
            ),
      );

  Future<bool> restart(String deploymentId) => _executeAction(
        () => ref.read(deploymentRepositoryProvider).restartDeployment(
              deploymentId,
            ),
      );

  Future<bool> destroy(String deploymentId) => _executeAction(
        () => ref.read(deploymentRepositoryProvider).destroyDeployment(
              deploymentId,
            ),
      );

  Future<bool> deploy(String deploymentId) => _executeAction(
        () => ref.read(deploymentRepositoryProvider).deploy(deploymentId),
      );

  Future<bool> pause(String deploymentId) => _executeAction(
        () => ref.read(deploymentRepositoryProvider).pauseDeployment(
              deploymentId,
            ),
      );

  Future<bool> unpause(String deploymentId) => _executeAction(
        () => ref.read(deploymentRepositoryProvider).unpauseDeployment(
              deploymentId,
            ),
      );

  Future<bool> _executeAction(
    Future<dynamic> Function() action,
  ) async {
    state = const AsyncValue.loading();

    final result = await action();

    // ignore: avoid_dynamic_calls
    final isSuccess = result.isRight() as bool;
    if (isSuccess) {
      state = const AsyncValue.data(null);
      // Refresh the deployments list
      ref.invalidate(deploymentsProvider);
    } else {
      // ignore: avoid_dynamic_calls
      final failure = result.getLeft().toNullable() as Failure?;
      state = AsyncValue.error(
        failure?.displayMessage ?? 'Action failed',
        StackTrace.current,
      );
    }

    return isSuccess;
  }
}
