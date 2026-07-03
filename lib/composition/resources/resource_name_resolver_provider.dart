import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
import 'package:komodo_go/features/procedures/data/repositories/procedure_repository.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';
import 'package:komodo_go/shared/resources/providers/resource_name_resolver_provider.dart';

final composedResourceNameResolverProvider = Provider<ResourceNameResolver>((
  ref,
) {
  return (resourceRef) => _fetchName(ref, resourceRef);
});

Future<String?> _fetchName(Ref ref, ResourceRef resourceRef) async {
  switch (resourceRef.kind) {
    case ResourceKind.system:
      return 'System';
    case ResourceKind.servers:
      final repo = ref.watch(serverRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getServer(resourceRef.id);
      return result.fold((_) => null, (server) => server.name);
    case ResourceKind.stacks:
      final repo = ref.watch(stackRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getStack(resourceRef.id);
      return result.fold((_) => null, (stack) => stack.name);
    case ResourceKind.deployments:
      final repo = ref.watch(deploymentRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getDeployment(resourceRef.id);
      return result.fold((_) => null, (deployment) => deployment.name);
    case ResourceKind.builds:
      final repo = ref.watch(buildRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getBuild(resourceRef.id);
      return result.fold((_) => null, (build) => build.name);
    case ResourceKind.repos:
      final repo = ref.watch(repoRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getRepo(resourceRef.id);
      return result.fold((_) => null, (repo) => repo.name);
    case ResourceKind.procedures:
      final repo = ref.watch(procedureRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getProcedure(resourceRef.id);
      return result.fold((_) => null, (procedure) => procedure.name);
    case ResourceKind.actions:
      final repo = ref.watch(actionRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getAction(resourceRef.id);
      return result.fold((_) => null, (action) => action.name);
    case ResourceKind.builders:
    case ResourceKind.alerters:
    case ResourceKind.syncs:
    case ResourceKind.unknown:
      return null;
  }
}
