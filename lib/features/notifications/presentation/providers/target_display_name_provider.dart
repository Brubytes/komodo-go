import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/presentation/providers/target_name_cache_provider.dart';
import 'package:komodo_go/features/procedures/data/repositories/procedure_repository.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'target_display_name_provider.g.dart';

@riverpod
Future<String> targetDisplayName(Ref ref, ResourceTarget target) async {
  final active = ref.watch(activeConnectionProvider);
  final connectionId = active?.connectionId;
  if (connectionId == null || connectionId.isEmpty) {
    return target.displayName;
  }

  final cache = ref.read(targetNameCacheProvider.notifier);
  final existing = cache.peek(connectionId: connectionId, target: target);
  if (existing != null && existing.isNotEmpty) {
    return existing;
  }

  return cache.getOrFetch(
    connectionId: connectionId,
    target: target,
    fetch: () => _fetchName(ref, target),
  );
}

Future<String> _fetchName(Ref ref, ResourceTarget target) async {
  switch (target.type) {
    case ResourceTargetType.system:
      return target.displayName;
    case ResourceTargetType.server:
      final repo = ref.watch(serverRepositoryProvider);
      if (repo == null) return target.displayName;
      final result = await repo.getServer(target.id);
      return result.fold((_) => target.displayName, (server) => server.name);
    case ResourceTargetType.stack:
      final repo = ref.watch(stackRepositoryProvider);
      if (repo == null) return target.displayName;
      final result = await repo.getStack(target.id);
      return result.fold((_) => target.displayName, (stack) => stack.name);
    case ResourceTargetType.deployment:
      final repo = ref.watch(deploymentRepositoryProvider);
      if (repo == null) return target.displayName;
      final result = await repo.getDeployment(target.id);
      return result.fold(
        (_) => target.displayName,
        (deployment) => deployment.name,
      );
    case ResourceTargetType.build:
      final repo = ref.watch(buildRepositoryProvider);
      if (repo == null) return target.displayName;
      final result = await repo.getBuild(target.id);
      return result.fold((_) => target.displayName, (build) => build.name);
    case ResourceTargetType.repo:
      final repo = ref.watch(repoRepositoryProvider);
      if (repo == null) return target.displayName;
      final result = await repo.getRepo(target.id);
      return result.fold((_) => target.displayName, (repo) => repo.name);
    case ResourceTargetType.procedure:
      final repo = ref.watch(procedureRepositoryProvider);
      if (repo == null) return target.displayName;
      final result = await repo.getProcedure(target.id);
      return result.fold(
        (_) => target.displayName,
        (procedure) => procedure.name,
      );
    case ResourceTargetType.action:
      final repo = ref.watch(actionRepositoryProvider);
      if (repo == null) return target.displayName;
      final result = await repo.getAction(target.id);
      return result.fold((_) => target.displayName, (action) => action.name);
    case ResourceTargetType.builder:
    case ResourceTargetType.alerter:
    case ResourceTargetType.resourceSync:
    case ResourceTargetType.unknown:
      return target.displayName;
  }
}
