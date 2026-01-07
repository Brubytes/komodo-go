import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/data/models/semantic_version.dart';

enum UpdateStatus { queued, running, success, failed, canceled, unknown }

UpdateStatus updateStatusFromJson(Object? value) {
  if (value is! String) return UpdateStatus.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'queued' => UpdateStatus.queued,
    'running' => UpdateStatus.running,
    'success' => UpdateStatus.success,
    'failed' => UpdateStatus.failed,
    'canceled' => UpdateStatus.canceled,
    _ => UpdateStatus.unknown,
  };
}

class UpdateListItem {
  const UpdateListItem({
    required this.id,
    required this.operation,
    required this.startTs,
    required this.success,
    required this.username,
    required this.operatorName,
    required this.status,
    required this.version,
    required this.otherData,
    this.target,
  });

  final String id;
  final String operation;
  final int startTs;
  final bool success;
  final String username;
  final String operatorName;
  final ResourceTarget? target;
  final UpdateStatus status;
  final SemanticVersion version;
  final String otherData;

  factory UpdateListItem.fromJson(Map<String, dynamic> json) {
    return UpdateListItem(
      id: (json['id'] as String?) ?? '',
      operation: (json['operation'] as String?) ?? '',
      startTs: _readInt(json['start_ts']),
      success: (json['success'] as bool?) ?? false,
      username: (json['username'] as String?) ?? '',
      operatorName: (json['operator'] as String?) ?? '',
      target: ResourceTarget.tryFromJson(json['target']),
      status: updateStatusFromJson(json['status']),
      version: SemanticVersion.fromJson(json['version']),
      otherData: (json['other_data'] as String?) ?? '',
    );
  }

  DateTime get timestamp => _unixToDateTime(startTs);
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime _unixToDateTime(int unix) {
  if (unix <= 0) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final isMillis = unix >= 1000000000000;
  return DateTime.fromMillisecondsSinceEpoch(
    isMillis ? unix : unix * 1000,
    isUtc: true,
  );
}
