import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/presentation/providers/target_name_cache_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';
import 'package:komodo_go/shared/resources/providers/resource_name_resolver_provider.dart';
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
  final resolver = ref.watch(resourceNameResolverProvider);
  final name = await resolver(_resourceRefFor(target));
  final trimmed = name?.trim();
  return trimmed == null || trimmed.isEmpty ? target.displayName : trimmed;
}

ResourceRef _resourceRefFor(ResourceTarget target) {
  return ResourceRef(kind: _kindFor(target.type), id: target.id);
}

ResourceKind _kindFor(ResourceTargetType type) {
  return switch (type) {
    ResourceTargetType.system => ResourceKind.system,
    ResourceTargetType.server => ResourceKind.servers,
    ResourceTargetType.stack => ResourceKind.stacks,
    ResourceTargetType.deployment => ResourceKind.deployments,
    ResourceTargetType.build => ResourceKind.builds,
    ResourceTargetType.repo => ResourceKind.repos,
    ResourceTargetType.procedure => ResourceKind.procedures,
    ResourceTargetType.action => ResourceKind.actions,
    ResourceTargetType.builder => ResourceKind.builders,
    ResourceTargetType.alerter => ResourceKind.alerters,
    ResourceTargetType.resourceSync => ResourceKind.syncs,
    ResourceTargetType.unknown => ResourceKind.unknown,
  };
}
