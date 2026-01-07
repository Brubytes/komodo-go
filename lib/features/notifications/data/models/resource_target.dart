enum ResourceTargetType {
  system,
  server,
  stack,
  deployment,
  build,
  repo,
  procedure,
  action,
  builder,
  alerter,
  resourceSync,
  unknown,
}

class ResourceTarget {
  const ResourceTarget({required this.type, required this.id});

  final ResourceTargetType type;
  final String id;

  static ResourceTarget? tryFromJson(Object? json) {
    if (json == null) return null;

    if (json is String) {
      return ResourceTarget(type: ResourceTargetType.unknown, id: json);
    }

    if (json is Map) {
      // Common enum encoding: { "Server": "id" }
      if (json.length == 1) {
        final entry = json.entries.first;
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is String) {
          return ResourceTarget(type: _typeFromVariant(key), id: value);
        }
      }

      // Fallback shapes (best-effort)
      final type = json['type'];
      final id = json['id'];
      if (type is String && id is String) {
        return ResourceTarget(type: _typeFromVariant(type), id: id);
      }
    }

    return null;
  }

  String get displayName {
    return switch (type) {
      ResourceTargetType.system => 'System',
      ResourceTargetType.server => 'Server',
      ResourceTargetType.stack => 'Stack',
      ResourceTargetType.deployment => 'Deployment',
      ResourceTargetType.build => 'Build',
      ResourceTargetType.repo => 'Repo',
      ResourceTargetType.procedure => 'Procedure',
      ResourceTargetType.action => 'Action',
      ResourceTargetType.builder => 'Builder',
      ResourceTargetType.alerter => 'Alerter',
      ResourceTargetType.resourceSync => 'Resource sync',
      ResourceTargetType.unknown => 'Resource',
    };
  }
}

ResourceTargetType _typeFromVariant(String value) {
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
    _ => ResourceTargetType.unknown,
  };
}
