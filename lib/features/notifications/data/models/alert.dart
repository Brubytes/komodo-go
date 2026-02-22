import 'package:komodo_go/features/notifications/data/models/resource_target.dart';

enum SeverityLevel { ok, warning, critical, unknown }

SeverityLevel severityLevelFromJson(Object? value) {
  if (value is! String) return SeverityLevel.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'ok' => SeverityLevel.ok,
    'warning' => SeverityLevel.warning,
    'critical' => SeverityLevel.critical,
    _ => SeverityLevel.unknown,
  };
}

class AlertPayload {
  const AlertPayload({required this.variant, required this.data});

  factory AlertPayload.fromJson(Object? json) {
    if (json is Map) {
      final map = json.map((k, v) => MapEntry(k.toString(), v));

      final taggedVariant =
          _readVariant(map['type']) ?? _readVariant(map['variant']);
      if (taggedVariant != null) {
        final taggedData =
            _asStringKeyedMap(
                    map['data'] ??
                        map['payload'] ??
                        map['params'] ??
                        map['value'],
                  ) ??
                  Map<String, dynamic>.from(map)
              ..removeWhere((key, _) => key == 'type' || key == 'variant');
        return AlertPayload(variant: taggedVariant, data: taggedData);
      }

      final entries = map.entries.toList();
      if (entries.length == 1) {
        final variant = entries.first.key;
        final value = entries.first.value;
        final data = _asStringKeyedMap(value) ?? <String, dynamic>{};
        return AlertPayload(variant: variant, data: data);
      }
    }

    return const AlertPayload(variant: 'Unknown', data: <String, dynamic>{});
  }

  final String variant;
  final Map<String, dynamic> data;

  String get displayTitle {
    if (variant.isEmpty) return 'Alert';
    return _humanizeVariant(variant);
  }

  String? get primaryName {
    final name = data['name'];
    if (name is String && name.isNotEmpty) return name;

    final serverName = data['server_name'];
    if (serverName is String && serverName.isNotEmpty) return serverName;

    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;

    return null;
  }
}

class Alert {
  const Alert({
    required this.id,
    required this.ts,
    required this.resolved,
    required this.level,
    required this.payload,
    this.target,
    this.resolvedTs,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: _readId(json),
      ts: _readInt(json['ts']),
      resolved: (json['resolved'] as bool?) ?? false,
      level: severityLevelFromJson(json['level']),
      target: ResourceTarget.tryFromJson(json['target']),
      payload: AlertPayload.fromJson(json['data']),
      resolvedTs: _readNullableInt(json['resolved_ts']),
    );
  }

  final String id;
  final int ts;
  final bool resolved;
  final SeverityLevel level;
  final ResourceTarget? target;
  final AlertPayload payload;
  final int? resolvedTs;

  DateTime get timestamp => _unixToDateTime(ts);
}

String _readId(Map<String, dynamic> json) {
  final id = json['id'];
  if (id is String && id.isNotEmpty) return id;

  final raw = json['_id'];
  if (raw is Map) {
    final oid = raw[r'$oid'];
    if (oid is String && oid.isNotEmpty) return oid;
  }
  if (raw is String && raw.isNotEmpty) return raw;

  return '';
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _readNullableInt(Object? value) {
  if (value == null) return null;
  return _readInt(value);
}

DateTime _unixToDateTime(int unix) {
  if (unix <= 0) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  // Heuristic: >= 1e12 is likely ms, otherwise seconds.
  final isMillis = unix >= 1000000000000;
  return DateTime.fromMillisecondsSinceEpoch(
    isMillis ? unix : unix * 1000,
    isUtc: true,
  );
}

String _humanizeVariant(String value) {
  // "ServerUnreachable" -> "Server unreachable"
  final withSpaces = value.replaceAllMapped(
    RegExp('(?<=[a-z0-9])(?=[A-Z])'),
    (_) => ' ',
  );
  if (withSpaces.isEmpty) return value;
  return withSpaces[0].toUpperCase() + withSpaces.substring(1);
}

String? _readVariant(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Map<String, dynamic>? _asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}
