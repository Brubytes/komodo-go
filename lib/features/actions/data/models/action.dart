import 'package:freezed_annotation/freezed_annotation.dart';

part 'action.freezed.dart';
part 'action.g.dart';

/// Action list item returned by `ListActions` (`ActionListItem` in `komodo_client`).
@freezed
sealed class ActionListItem with _$ActionListItem {
  const factory ActionListItem({
    required String id,
    required String name,
    required ActionListItemInfo info, @Default(false) bool template,
    @Default([]) List<String> tags,
  }) = _ActionListItem;

  factory ActionListItem.fromJson(Map<String, dynamic> json) =>
      _$ActionListItemFromJson(json);
}

/// Action info returned by `ListActions` (`ActionListItemInfo` in `komodo_client`).
@freezed
sealed class ActionListItemInfo with _$ActionListItemInfo {
  const factory ActionListItemInfo({
    @JsonKey(fromJson: _actionStateFromJson, toJson: _actionStateToJson)
    @Default(ActionState.unknown)
    ActionState state,
    @JsonKey(name: 'last_run_at') int? lastRunAt,
    @JsonKey(name: 'next_scheduled_run') int? nextScheduledRun,
    @JsonKey(name: 'schedule_error') String? scheduleError,
  }) = _ActionListItemInfo;

  factory ActionListItemInfo.fromJson(Map<String, dynamic> json) =>
      _$ActionListItemInfoFromJson(json);
}

/// Action returned by `GetAction` (`Action` in `komodo_client`).
@freezed
sealed class KomodoAction with _$KomodoAction {
  const factory KomodoAction({
    @JsonKey(readValue: _readId) required String id,
    required String name,
    required ActionConfig config, @Default('') String description,
    @Default(false) bool template,
    @Default([]) List<String> tags,
  }) = _KomodoAction;

  factory KomodoAction.fromJson(Map<String, dynamic> json) =>
      _$KomodoActionFromJson(json);
}

/// Reads the id from either 'id' or '_id.$oid' format.
Object? _readId(Map<dynamic, dynamic> json, String key) {
  if (json.containsKey('id')) {
    return json['id'];
  }
  if (json.containsKey('_id')) {
    final id = json['_id'];
    if (id is Map && id.containsKey(r'$oid')) {
      return id[r'$oid'];
    }
    return id;
  }
  return null;
}

/// Action configuration (`ActionConfig` in `komodo_client`).
@freezed
sealed class ActionConfig with _$ActionConfig {
  const factory ActionConfig({
    @JsonKey(name: 'run_at_startup') @Default(false) bool runAtStartup,
    @JsonKey(
      name: 'schedule_format',
      fromJson: _scheduleFormatFromJson,
      toJson: _scheduleFormatToJson,
    )
    @Default(ScheduleFormat.english)
    ScheduleFormat scheduleFormat,
    @Default('') String schedule,
    @JsonKey(name: 'schedule_enabled') @Default(false) bool scheduleEnabled,
    @JsonKey(name: 'schedule_timezone') @Default('') String scheduleTimezone,
    @JsonKey(name: 'schedule_alert') @Default(false) bool scheduleAlert,
    @JsonKey(name: 'failure_alert') @Default(false) bool failureAlert,
    @JsonKey(name: 'webhook_enabled') @Default(false) bool webhookEnabled,
    @JsonKey(name: 'webhook_secret') @Default('') String webhookSecret,
    @JsonKey(name: 'reload_deno_deps') @Default(false) bool reloadDenoDeps,
    @JsonKey(name: 'file_contents') @Default('') String fileContents,
    @JsonKey(
      name: 'arguments_format',
      fromJson: _fileFormatFromJson,
      toJson: _fileFormatToJson,
    )
    @Default(FileFormat.keyValue)
    FileFormat argumentsFormat,
    @Default('') String arguments,
  }) = _ActionConfig;

  factory ActionConfig.fromJson(Map<String, dynamic> json) =>
      _$ActionConfigFromJson(json);
}

enum ActionState { unknown, ok, failed, running }

ActionState _actionStateFromJson(Object? value) {
  if (value is! String) return ActionState.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'running' => ActionState.running,
    'ok' => ActionState.ok,
    'failed' => ActionState.failed,
    _ => ActionState.unknown,
  };
}

String _actionStateToJson(ActionState value) {
  return switch (value) {
    ActionState.running => 'Running',
    ActionState.ok => 'Ok',
    ActionState.failed => 'Failed',
    ActionState.unknown => 'Unknown',
  };
}

extension ActionStateX on ActionState {
  bool get isRunning => this == ActionState.running;

  String get displayName {
    return switch (this) {
      ActionState.running => 'Running',
      ActionState.ok => 'Ok',
      ActionState.failed => 'Failed',
      ActionState.unknown => 'Unknown',
    };
  }
}

enum ScheduleFormat { english, cron }

ScheduleFormat _scheduleFormatFromJson(Object? value) {
  if (value is! String) return ScheduleFormat.english;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'cron' => ScheduleFormat.cron,
    'english' => ScheduleFormat.english,
    _ => ScheduleFormat.english,
  };
}

String _scheduleFormatToJson(ScheduleFormat value) {
  return switch (value) {
    ScheduleFormat.english => 'English',
    ScheduleFormat.cron => 'Cron',
  };
}

enum FileFormat { keyValue, toml, yaml, json }

FileFormat _fileFormatFromJson(Object? value) {
  if (value is! String) return FileFormat.keyValue;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'keyvalue' => FileFormat.keyValue,
    'toml' => FileFormat.toml,
    'yaml' => FileFormat.yaml,
    'json' => FileFormat.json,
    _ => FileFormat.keyValue,
  };
}

String _fileFormatToJson(FileFormat value) {
  return switch (value) {
    FileFormat.keyValue => 'KeyValue',
    FileFormat.toml => 'Toml',
    FileFormat.yaml => 'Yaml',
    FileFormat.json => 'Json',
  };
}

extension FileFormatX on FileFormat {
  String get displayName {
    return switch (this) {
      FileFormat.keyValue => 'KeyValue',
      FileFormat.toml => 'TOML',
      FileFormat.yaml => 'YAML',
      FileFormat.json => 'JSON',
    };
  }
}
