import 'package:freezed_annotation/freezed_annotation.dart';

part 'alerter.freezed.dart';

@freezed
sealed class AlerterDetail with _$AlerterDetail {
  const factory AlerterDetail({
    required String id,
    required String name,
    required String updatedAt,
    required AlerterConfig config,
  }) = _AlerterDetail;

  const AlerterDetail._();

  factory AlerterDetail.fromApiJson(Map<String, dynamic> json) {
    final nested = json['alerter'];
    final nestedMap = nested is Map ? Map<String, dynamic>.from(nested) : null;
    final name = (nestedMap?['name'] ?? json['name'] ?? '').toString().trim();
    final id = (nestedMap?['id'] ?? json['id'] ?? name).toString().trim();
    final updatedAt = (json['updated_at'] ?? nestedMap?['updated_at'] ?? '')
        .toString();
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

@freezed
sealed class AlerterConfig with _$AlerterConfig {
  const factory AlerterConfig({
    @Default(false) bool enabled,
    AlerterEndpoint? endpoint,
    @Default([]) List<String> alertTypes,
    @Default([]) List<AlerterResourceTarget> resources,
    @Default([]) List<AlerterResourceTarget> exceptResources,
    @Default([]) List<AlerterMaintenanceWindow> maintenanceWindows,
  }) = _AlerterConfig;

  const AlerterConfig._();

  factory AlerterConfig.fromApiMap(Map<String, dynamic> map) {
    final enabled = _toBool(map['enabled']) ?? false;
    return AlerterConfig(
      enabled: enabled,
      endpoint: AlerterEndpoint.fromApi(map['endpoint']),
      alertTypes: _readStringList(map['alert_types']),
      resources: AlerterResourceTarget.parseList(map['resources']),
      exceptResources: AlerterResourceTarget.parseList(map['except_resources']),
      maintenanceWindows: AlerterMaintenanceWindow.parseList(
        map['maintenance_windows'],
      ),
    );
  }
}

@freezed
sealed class AlerterEndpoint with _$AlerterEndpoint {
  const factory AlerterEndpoint({
    required String type,
    String? url,
    String? email,
  }) = _AlerterEndpoint;

  const AlerterEndpoint._();

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

@freezed
sealed class AlerterResourceTarget with _$AlerterResourceTarget {
  const factory AlerterResourceTarget({
    required String variant,
    required String value,
    String? name,
  }) = _AlerterResourceTarget;

  const AlerterResourceTarget._();

  String get key => '${variant.toLowerCase()}:$value';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': variant,
    'id': value,
  };

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
          out.add(
            AlerterResourceTarget(variant: type.trim(), value: id.trim()),
          );
        }
      }
    }
    return out;
  }
}

@freezed
sealed class AlerterMaintenanceWindow with _$AlerterMaintenanceWindow {
  const factory AlerterMaintenanceWindow({
    @Default('') String name,
    @Default('') String description,
    @Default('') String scheduleType,
    @Default('') String dayOfWeek,
    @Default('') String date,
    @Default(0) int hour,
    @Default(0) int minute,
    @Default(60) int durationMinutes,
    @Default('UTC') String timezone,
    @Default(true) bool enabled,
  }) = _AlerterMaintenanceWindow;

  const AlerterMaintenanceWindow._();

  factory AlerterMaintenanceWindow.fromApiMap(Map<String, dynamic> map) {
    return AlerterMaintenanceWindow(
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      scheduleType: (map['schedule_type'] ?? '').toString(),
      dayOfWeek: (map['day_of_week'] ?? '').toString(),
      date: (map['date'] ?? '').toString(),
      hour: _readInt(map['hour']) ?? 0,
      minute: _readInt(map['minute']) ?? 0,
      durationMinutes: _readInt(map['duration_minutes']) ?? 60,
      timezone: (map['timezone'] ?? 'UTC').toString(),
      enabled: _toBool(map['enabled']) ?? true,
    );
  }

  Map<String, dynamic> toApiMap() => <String, dynamic>{
    'name': name,
    'description': description,
    'schedule_type': scheduleType,
    'day_of_week': dayOfWeek,
    'date': date,
    'hour': hour,
    'minute': minute,
    'duration_minutes': durationMinutes,
    'timezone': timezone,
    'enabled': enabled,
  };

  static List<AlerterMaintenanceWindow> parseList(Object? raw) {
    if (raw is! List) return const <AlerterMaintenanceWindow>[];
    final out = <AlerterMaintenanceWindow>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(
          AlerterMaintenanceWindow.fromApiMap(Map<String, dynamic>.from(e)),
        );
      }
    }
    return out;
  }
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

int? _readInt(Object? v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}
