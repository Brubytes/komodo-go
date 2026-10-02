import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/data/models/semantic_version.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';

class UpdateDetail {
  const UpdateDetail({
    required this.id,
    required this.operation,
    required this.startTs,
    required this.success,
    required this.operatorName,
    required this.logs,
    required this.status,
    required this.version,
    required this.commitHash,
    required this.otherData,
    required this.previousToml,
    required this.currentToml,
    this.target,
    this.endTs,
  });

  factory UpdateDetail.fromJson(Map<String, dynamic> json) {
    final success = (json['success'] as bool?) ?? false;
    return UpdateDetail(
      id: _readId(json),
      operation: json['operation']?.toString() ?? '',
      startTs: _readInt(json['start_ts']),
      success: success,
      operatorName: json['operator']?.toString() ?? '',
      target: ResourceTarget.tryFromJson(json['target']),
      logs: [
        for (final item in (json['logs'] as List<dynamic>? ?? const []))
          if (item is Map) UpdateLog.fromJson(item.cast<String, dynamic>()),
      ],
      endTs: _readNullableInt(json['end_ts']),
      status: updateStatusFromJson(json['status'], success: success),
      version: SemanticVersion.fromJson(json['version']),
      commitHash: json['commit_hash']?.toString() ?? '',
      otherData: json['other_data']?.toString() ?? '',
      previousToml: json['prev_toml']?.toString() ?? '',
      currentToml: json['current_toml']?.toString() ?? '',
    );
  }

  final String id;
  final String operation;
  final int startTs;
  final bool success;
  final String operatorName;
  final ResourceTarget? target;
  final List<UpdateLog> logs;
  final int? endTs;
  final UpdateStatus status;
  final SemanticVersion version;
  final String commitHash;
  final String otherData;
  final String previousToml;
  final String currentToml;

  DateTime get startedAt => _unixToDateTime(startTs);
  DateTime? get endedAt => endTs == null ? null : _unixToDateTime(endTs!);

  Duration? get duration {
    final end = endedAt;
    if (end == null) return null;
    final value = end.difference(startedAt);
    return value.isNegative ? Duration.zero : value;
  }
}

class UpdateLog {
  const UpdateLog({
    required this.stage,
    required this.command,
    required this.stdout,
    required this.stderr,
    required this.success,
    required this.startTs,
    required this.endTs,
  });

  factory UpdateLog.fromJson(Map<String, dynamic> json) {
    return UpdateLog(
      stage: json['stage']?.toString() ?? '',
      command: json['command']?.toString() ?? '',
      stdout: json['stdout']?.toString() ?? '',
      stderr: json['stderr']?.toString() ?? '',
      success: (json['success'] as bool?) ?? false,
      startTs: _readInt(json['start_ts']),
      endTs: _readInt(json['end_ts']),
    );
  }

  final String stage;
  final String command;
  final String stdout;
  final String stderr;
  final bool success;
  final int startTs;
  final int endTs;

  Duration get duration {
    final value = _unixToDateTime(endTs).difference(_unixToDateTime(startTs));
    return value.isNegative ? Duration.zero : value;
  }
}

String _readId(Map<String, dynamic> json) {
  final id = json['id'] ?? json['_id'];
  if (id is Map && id[r'$oid'] != null) return id[r'$oid'].toString();
  return id?.toString() ?? '';
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
  final isMillis = unix >= 1000000000000;
  return DateTime.fromMillisecondsSinceEpoch(
    isMillis ? unix : unix * 1000,
    isUtc: true,
  );
}
