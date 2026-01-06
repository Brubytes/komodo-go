import 'package:freezed_annotation/freezed_annotation.dart';

part 'procedure.freezed.dart';
part 'procedure.g.dart';

/// Procedure list item returned by `ListProcedures` (`ProcedureListItem` in `komodo_client`).
@freezed
sealed class ProcedureListItem with _$ProcedureListItem {
  const factory ProcedureListItem({
    required String id,
    required String name,
    @Default(false) bool template,
    @Default([]) List<String> tags,
    required ProcedureListItemInfo info,
  }) = _ProcedureListItem;

  factory ProcedureListItem.fromJson(Map<String, dynamic> json) =>
      _$ProcedureListItemFromJson(json);
}

/// Procedure info returned by `ListProcedures` (`ProcedureListItemInfo` in `komodo_client`).
@freezed
sealed class ProcedureListItemInfo with _$ProcedureListItemInfo {
  const factory ProcedureListItemInfo({
    @Default(0) int stages,
    @JsonKey(fromJson: _procedureStateFromJson, toJson: _procedureStateToJson)
    @Default(ProcedureState.unknown)
    ProcedureState state,
    @JsonKey(name: 'last_run_at') int? lastRunAt,
    @JsonKey(name: 'next_scheduled_run') int? nextScheduledRun,
    @JsonKey(name: 'schedule_error') String? scheduleError,
  }) = _ProcedureListItemInfo;

  factory ProcedureListItemInfo.fromJson(Map<String, dynamic> json) =>
      _$ProcedureListItemInfoFromJson(json);
}

/// Procedure returned by `GetProcedure` (`Procedure` in `komodo_client`).
@freezed
sealed class KomodoProcedure with _$KomodoProcedure {
  const factory KomodoProcedure({
    @JsonKey(readValue: _readId) required String id,
    required String name,
    @Default('') String description,
    @Default(false) bool template,
    @Default([]) List<String> tags,
    required ProcedureConfig config,
  }) = _KomodoProcedure;

  factory KomodoProcedure.fromJson(Map<String, dynamic> json) =>
      _$KomodoProcedureFromJson(json);
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

/// Procedure configuration (`ProcedureConfig` in `komodo_client`).
@freezed
sealed class ProcedureConfig with _$ProcedureConfig {
  const factory ProcedureConfig({
    @Default([]) List<ProcedureStage> stages,
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
  }) = _ProcedureConfig;

  factory ProcedureConfig.fromJson(Map<String, dynamic> json) =>
      _$ProcedureConfigFromJson(json);
}

/// A single stage of a procedure.
@freezed
sealed class ProcedureStage with _$ProcedureStage {
  const factory ProcedureStage({
    @Default('') String name,
    @Default(true) bool enabled,
    @Default([]) List<EnabledExecution> executions,
  }) = _ProcedureStage;

  factory ProcedureStage.fromJson(Map<String, dynamic> json) =>
      _$ProcedureStageFromJson(json);
}

/// Execution wrapper with enabled flag.
@freezed
sealed class EnabledExecution with _$EnabledExecution {
  const factory EnabledExecution({
    @JsonKey(name: 'execution') dynamic execution,
    @Default(true) bool enabled,
  }) = _EnabledExecution;

  factory EnabledExecution.fromJson(Map<String, dynamic> json) =>
      _$EnabledExecutionFromJson(json);
}

enum ProcedureState { running, ok, failed, unknown }

ProcedureState _procedureStateFromJson(Object? value) {
  if (value is! String) return ProcedureState.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'running' => ProcedureState.running,
    'ok' => ProcedureState.ok,
    'failed' => ProcedureState.failed,
    _ => ProcedureState.unknown,
  };
}

String _procedureStateToJson(ProcedureState value) {
  return switch (value) {
    ProcedureState.running => 'Running',
    ProcedureState.ok => 'Ok',
    ProcedureState.failed => 'Failed',
    ProcedureState.unknown => 'Unknown',
  };
}

extension ProcedureStateX on ProcedureState {
  bool get isRunning => this == ProcedureState.running;

  String get displayName {
    return switch (this) {
      ProcedureState.running => 'Running',
      ProcedureState.ok => 'Ok',
      ProcedureState.failed => 'Failed',
      ProcedureState.unknown => 'Unknown',
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
