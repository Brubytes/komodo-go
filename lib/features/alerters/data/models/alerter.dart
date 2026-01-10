class AlerterDetail {
  const AlerterDetail({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.config,
  });

  final String id;
  final String name;
  final String updatedAt;
  final AlerterConfig config;

  factory AlerterDetail.fromApiJson(Map<String, dynamic> json) {
    final nested = json['alerter'];
    final nestedMap =
        nested is Map ? Map<String, dynamic>.from(nested) : null;
    final name =
        (nestedMap?['name'] ?? json['name'] ?? '').toString().trim();
    final id =
        (nestedMap?['id'] ?? json['id'] ?? name).toString().trim();
    final updatedAt =
        (json['updated_at'] ?? nestedMap?['updated_at'] ?? '').toString();
    final configRaw = json['config'];
    final configMap = configRaw is Map
        ? Map<String, dynamic>.from(configRaw)
        : <String, dynamic>{};
    return AlerterDetail(
      id: id,
      name: name,
      updatedAt: updatedAt,
      config: AlerterConfig.fromApiMap(configMap),
    );
  }
}

class AlerterConfig {
  const AlerterConfig({
    required this.enabled,
    required this.endpoint,
    required this.alertTypes,
    required this.resources,
    required this.exceptResources,
    required this.maintenanceWindows,
  });

  final bool enabled;
  final AlerterEndpoint? endpoint;
  final List<String> alertTypes;
  final List<AlerterResourceTarget> resources;
  final List<AlerterResourceTarget> exceptResources;
  final List<Map<String, dynamic>> maintenanceWindows;

  factory AlerterConfig.fromApiMap(Map<String, dynamic> map) {
    final enabled = _toBool(map['enabled']) ?? false;
    return AlerterConfig(
      enabled: enabled,
      endpoint: AlerterEndpoint.fromApi(map['endpoint']),
      alertTypes: _readStringList(map['alert_types']),
      resources: AlerterResourceTarget.parseList(map['resources']),
      exceptResources: AlerterResourceTarget.parseList(map['except_resources']),
      maintenanceWindows: _parseMaintenanceWindows(
        map['maintenance_windows'],
      ),
    );
  }
}

class AlerterEndpoint {
  const AlerterEndpoint({required this.type, this.url, this.email});

  final String type;
  final String? url;
  final String? email;

  static AlerterEndpoint? fromApi(Object? raw) {
    if (raw is Map<String, dynamic>) {
      final type = raw['type']?.toString().trim();
      final params = raw['params'];
      if (type != null && type.isNotEmpty && params is Map) {
        final map = Map<String, dynamic>.from(params);
        return AlerterEndpoint(
          type: type,
          url: map['url']?.toString(),
          email: map['email']?.toString(),
        );
      }

      if (raw.length == 1) {
        final entry = raw.entries.first;
        if (entry.value is Map) {
          final inner = Map<String, dynamic>.from(entry.value as Map);
          return AlerterEndpoint(
            type: entry.key,
            url: inner['url']?.toString(),
            email: inner['email']?.toString(),
          );
        }
      }
    }
    return null;
  }

  Map<String, dynamic> toApiPayload() {
    final params = <String, dynamic>{'url': url ?? ''};
    if (type == 'Ntfy' && (email ?? '').isNotEmpty) {
      params['email'] = email;
    }
    return <String, dynamic>{'type': type, 'params': params};
  }
}

class AlerterResourceTarget {
  const AlerterResourceTarget({
    required this.variant,
    required this.value,
    this.name,
  });

  final String variant;
  final String value;
  final String? name;

  String get key => '${variant.toLowerCase()}:$value';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': variant,
        'id': value,
      };

  AlerterResourceTarget copyWith({String? name}) {
    return AlerterResourceTarget(
      variant: variant,
      value: value,
      name: name ?? this.name,
    );
  }

  static List<AlerterResourceTarget> parseList(Object? raw) {
    if (raw is! List) return const <AlerterResourceTarget>[];

    final out = <AlerterResourceTarget>[];
    for (final e in raw) {
      if (e is Map && e.length == 1) {
        final entry = e.entries.first;
        final k = entry.key?.toString();
        final v = entry.value?.toString();
        if (k != null &&
            v != null &&
            k.trim().isNotEmpty &&
            v.trim().isNotEmpty) {
          out.add(AlerterResourceTarget(variant: k.trim(), value: v.trim()));
        }
        continue;
      }
      if (e is Map) {
        final type = e['type']?.toString();
        final id = e['id']?.toString();
        if (type != null &&
            id != null &&
            type.trim().isNotEmpty &&
            id.trim().isNotEmpty) {
          out.add(AlerterResourceTarget(variant: type.trim(), value: id.trim()));
        }
      }
    }
    return out;
  }
}

List<Map<String, dynamic>> _parseMaintenanceWindows(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  final out = <Map<String, dynamic>>[];
  for (final e in raw) {
    if (e is Map) out.add(Map<String, dynamic>.from(e));
  }
  return out;
}

List<String> _readStringList(Object? v) {
  if (v is List) {
    return v.map((e) => e?.toString()).whereType<String>().toList();
  }
  return const <String>[];
}

bool? _toBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
  }
  return null;
}
