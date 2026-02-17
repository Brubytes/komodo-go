import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';

String? routeForAlert(Alert alert) {
  final direct = routeForTarget(alert.target);
  if (direct != null) return direct;

  final inferred = _inferTargetFromPayload(alert.payload);
  return routeForTarget(inferred);
}

String? routeForUpdate(UpdateListItem update) {
  return routeForTarget(update.target);
}

String? routeForTarget(ResourceTarget? target) {
  if (target == null) return null;

  final id = Uri.encodeComponent(target.id);

  return switch (target.type) {
    ResourceTargetType.server => '${AppRoutes.servers}/$id',
    ResourceTargetType.stack => '${AppRoutes.stacks}/$id',
    ResourceTargetType.deployment => '${AppRoutes.deployments}/$id',
    ResourceTargetType.build => '${AppRoutes.builds}/$id',
    ResourceTargetType.repo => '${AppRoutes.repos}/$id',
    ResourceTargetType.procedure => '${AppRoutes.procedures}/$id',
    ResourceTargetType.action => '${AppRoutes.actions}/$id',
    ResourceTargetType.resourceSync => '${AppRoutes.syncs}/$id',
    ResourceTargetType.alerter => '${AppRoutes.komodoAlerters}/$id',
    ResourceTargetType.builder => AppRoutes.komodoBuilders,
    ResourceTargetType.system => AppRoutes.settings,
    ResourceTargetType.unknown => null,
  };
}

ResourceTarget? _inferTargetFromPayload(AlertPayload payload) {
  final data = payload.data;

  if (payload.variant == 'ScheduleRun') {
    final type = _typeFromDynamic(data['resource_type']);
    final id = _readString(data['id']);
    if (type != null && id != null) {
      return ResourceTarget(type: type, id: id);
    }
  }

  final type = _typeFromAlertVariant(payload.variant);
  final id =
      _readString(data['id']) ??
      _readString(data['resource_id']) ??
      _readString(data['server_id']) ??
      _readString(data['deployment_id']) ??
      _readString(data['stack_id']) ??
      _readString(data['build_id']) ??
      _readString(data['repo_id']) ??
      _readString(data['procedure_id']) ??
      _readString(data['action_id']) ??
      _readString(data['sync_id']) ??
      _readString(data['alerter_id']) ??
      _readString(data['builder_id']);

  if (type == null || id == null) return null;
  return ResourceTarget(type: type, id: id);
}

ResourceTargetType? _typeFromDynamic(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');

  return switch (normalized) {
    'system' => ResourceTargetType.system,
    'server' => ResourceTargetType.server,
    'stack' => ResourceTargetType.stack,
    'deployment' => ResourceTargetType.deployment,
    'build' => ResourceTargetType.build,
    'repo' => ResourceTargetType.repo,
    'procedure' => ResourceTargetType.procedure,
    'action' => ResourceTargetType.action,
    'builder' => ResourceTargetType.builder,
    'alerter' => ResourceTargetType.alerter,
    'resourcesync' => ResourceTargetType.resourceSync,
    _ => null,
  };
}

ResourceTargetType? _typeFromAlertVariant(String variant) {
  return switch (variant) {
    'ServerUnreachable' ||
    'ServerCpu' ||
    'ServerMem' ||
    'ServerDisk' ||
    'ServerVersionMismatch' => ResourceTargetType.server,
    'ContainerStateChange' ||
    'DeploymentImageUpdateAvailable' ||
    'DeploymentAutoUpdated' => ResourceTargetType.deployment,
    'StackStateChange' ||
    'StackImageUpdateAvailable' ||
    'StackAutoUpdated' => ResourceTargetType.stack,
    'ResourceSyncPendingUpdates' => ResourceTargetType.resourceSync,
    'BuildFailed' => ResourceTargetType.build,
    'RepoBuildFailed' => ResourceTargetType.repo,
    'ProcedureFailed' => ResourceTargetType.procedure,
    'ActionFailed' => ResourceTargetType.action,
    'AwsBuilderTerminationFailed' => ResourceTargetType.builder,
    _ => null,
  };
}

String? _readString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
