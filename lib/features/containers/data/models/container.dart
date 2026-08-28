import 'package:freezed_annotation/freezed_annotation.dart';

part 'container.freezed.dart';
part 'container.g.dart';

/// Container summary returned by `ListContainers` (`ContainerListItem` in `komodo_client`).
@freezed
sealed class ContainerListItem with _$ContainerListItem {
  const factory ContainerListItem({
    @JsonKey(name: 'server_id') String? serverId,
    @JsonKey(name: 'server_name') String? serverName,
    @Default('') String name,
    String? id,
    String? image,
    String? status,
    @JsonKey(fromJson: _containerStateFromJson, toJson: _containerStateToJson)
    @Default(ContainerState.unknown)
    ContainerState state,
    @Default([]) List<String> networks,
    @JsonKey(readValue: _readPorts) @Default([]) List<ContainerPort> ports,
    ContainerStats? stats,
  }) = _ContainerListItem;

  factory ContainerListItem.fromJson(Map<String, dynamic> json) =>
      _$ContainerListItemFromJson(json);
}

@freezed
sealed class ContainerPort with _$ContainerPort {
  const factory ContainerPort({
    @JsonKey(readValue: _readPortIp) String? ip,
    @JsonKey(readValue: _readPortPrivate) @Default(0) int privatePort,
    @JsonKey(readValue: _readPortPublic) int? publicPort,
    @JsonKey(
      readValue: _readPortType,
      fromJson: _portTypeFromJson,
      toJson: _portTypeToJson,
    )
    @Default(PortType.unknown)
    PortType type,
  }) = _ContainerPort;

  factory ContainerPort.fromJson(Map<String, dynamic> json) =>
      _$ContainerPortFromJson(json);
}

@freezed
sealed class ContainerStats with _$ContainerStats {
  const factory ContainerStats({
    @JsonKey(name: 'cpu_perc') @Default('') String cpuPerc,
    @JsonKey(name: 'mem_perc') @Default('') String memPerc,
    @JsonKey(name: 'mem_usage') @Default('') String memUsage,
    @JsonKey(name: 'net_io') @Default('') String netIo,
    @JsonKey(name: 'block_io') @Default('') String blockIo,
    @Default('') String pids,
  }) = _ContainerStats;

  const ContainerStats._();

  factory ContainerStats.fromJson(Map<String, dynamic> json) =>
      _$ContainerStatsFromJson(json);

  double? get cpuPercentValue => _parsePercent(cpuPerc);

  double? get memPercentValue => _parsePercent(memPerc) ?? _memUsagePercent;

  double? get memUsageBytes {
    final parsed = _parseBytePair(memUsage);
    return parsed.used;
  }

  double? get memLimitBytes {
    final parsed = _parseBytePair(memUsage);
    return parsed.total;
  }

  double? get netIoTotalBytes => _parseBytePairTotal(netIo);

  double? get blockIoTotalBytes => _parseBytePairTotal(blockIo);

  int? get pidsValue => int.tryParse(pids.trim());

  double? get _memUsagePercent {
    final parsed = _parseBytePair(memUsage);
    final used = parsed.used;
    final total = parsed.total;
    if (used == null || total == null || total <= 0) return null;
    return (used / total) * 100.0;
  }
}

/// Selected inspection fields plus the full raw Docker inspect response.
class ContainerInspection {
  const ContainerInspection({
    required this.id,
    required this.name,
    required this.created,
    required this.path,
    required this.args,
    required this.image,
    required this.driver,
    required this.platform,
    required this.restartCount,
    required this.logPath,
    required this.mounts,
    required this.raw,
  });

  factory ContainerInspection.fromJson(Map<String, dynamic> json) {
    final mounts = _readList(json, 'mounts', 'Mounts');
    return ContainerInspection(
      id: _readString(json, 'id', 'Id'),
      name: _readString(json, 'name', 'Name'),
      created: _readString(json, 'created', 'Created'),
      path: _readString(json, 'path', 'Path'),
      args: _readList(
        json,
        'args',
        'Args',
      ).whereType<String>().toList(growable: false),
      image: _readString(json, 'image', 'Image'),
      driver: _readString(json, 'driver', 'Driver'),
      platform: _readString(json, 'platform', 'Platform'),
      restartCount: _readNum(json, 'restart_count', 'RestartCount')?.toInt(),
      logPath: _readString(json, 'log_path', 'LogPath'),
      mounts: mounts
          .whereType<Map<Object?, Object?>>()
          .map(
            (mount) => <String, dynamic>{
              for (final entry in mount.entries)
                entry.key.toString().toLowerCase(): entry.value,
            },
          )
          .toList(growable: false),
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }

  final String? id;
  final String? name;
  final String? created;
  final String? path;
  final List<String> args;
  final String? image;
  final String? driver;
  final String? platform;
  final int? restartCount;
  final String? logPath;
  final List<Map<String, dynamic>> mounts;
  final Map<String, dynamic> raw;

  /// Stack name encoded by Komodo's compose working directory, when present.
  ///
  /// Komodo 2.3 can return no result from `GetResourceMatchingContainer` for
  /// stack containers. Its generated compose path still has the stable
  /// `.../stacks/<stack-name>/...` shape, which is safe to use as a fallback.
  String? get managedStackName {
    final config = raw['Config'];
    if (config is! Map<Object?, Object?>) return null;
    final labels = config['Labels'];
    if (labels is! Map<Object?, Object?>) return null;

    for (final key in const <String>[
      'com.docker.compose.project.working_dir',
      'com.docker.compose.project.config_files',
    ]) {
      final path = labels[key]?.toString();
      if (path == null || path.trim().isEmpty) continue;
      final match = RegExp(
        r'(?:^|[/\\])stacks[/\\]([^/\\,]+)',
      ).firstMatch(path);
      final name = match?.group(1)?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }
}

String? _readString(
  Map<String, dynamic> json,
  String canonicalKey,
  String dockerKey,
) => (json[canonicalKey] ?? json[dockerKey]) as String?;

num? _readNum(
  Map<String, dynamic> json,
  String canonicalKey,
  String dockerKey,
) => (json[canonicalKey] ?? json[dockerKey]) as num?;

List<dynamic> _readList(
  Map<String, dynamic> json,
  String canonicalKey,
  String dockerKey,
) => (json[canonicalKey] ?? json[dockerKey]) as List<dynamic>? ?? const [];

enum ContainerResourceType { stack, deployment }

class ContainerAssociatedResource {
  const ContainerAssociatedResource({required this.type, required this.id});

  factory ContainerAssociatedResource.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String? ?? '').toLowerCase();
    return ContainerAssociatedResource(
      type: type == 'stack'
          ? ContainerResourceType.stack
          : ContainerResourceType.deployment,
      id: json['id'] as String? ?? '',
    );
  }

  final ContainerResourceType type;
  final String id;
}

enum ContainerState {
  running,
  created,
  paused,
  restarting,
  exited,
  removing,
  dead,
  unknown,
}

ContainerState _containerStateFromJson(Object? value) {
  if (value is! String) return ContainerState.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'running' => ContainerState.running,
    'created' => ContainerState.created,
    'paused' => ContainerState.paused,
    'restarting' => ContainerState.restarting,
    'exited' => ContainerState.exited,
    'removing' => ContainerState.removing,
    'dead' => ContainerState.dead,
    _ => ContainerState.unknown,
  };
}

String _containerStateToJson(ContainerState value) {
  return switch (value) {
    ContainerState.running => 'Running',
    ContainerState.created => 'Created',
    ContainerState.paused => 'Paused',
    ContainerState.restarting => 'Restarting',
    ContainerState.exited => 'Exited',
    ContainerState.removing => 'Removing',
    ContainerState.dead => 'Dead',
    ContainerState.unknown => 'Unknown',
  };
}

enum PortType { tcp, udp, unknown }

PortType _portTypeFromJson(Object? value) {
  if (value is! String) return PortType.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'tcp' => PortType.tcp,
    'udp' => PortType.udp,
    _ => PortType.unknown,
  };
}

String _portTypeToJson(PortType value) {
  return switch (value) {
    PortType.tcp => 'Tcp',
    PortType.udp => 'Udp',
    PortType.unknown => 'Unknown',
  };
}

double? _parsePercent(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.replaceAll('%', '');
  return double.tryParse(normalized);
}

double? _parseByte(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(
    r'^([0-9]*\.?[0-9]+)\s*([a-zA-Z]+)?$',
  ).firstMatch(trimmed);
  if (match == null) return null;
  final value = double.tryParse(match.group(1) ?? '');
  if (value == null) return null;
  final unit = (match.group(2) ?? '').toLowerCase();

  const unitMap = <String, double>{
    'b': 1,
    'kb': 1024,
    'kib': 1024,
    'mb': 1024 * 1024,
    'mib': 1024 * 1024,
    'gb': 1024 * 1024 * 1024,
    'gib': 1024 * 1024 * 1024,
    'tb': 1024 * 1024 * 1024 * 1024,
    'tib': 1024 * 1024 * 1024 * 1024,
    'pb': 1024 * 1024 * 1024 * 1024 * 1024,
    'pib': 1024 * 1024 * 1024 * 1024 * 1024,
  };

  final multiplier = unitMap[unit] ?? 1;
  return value * multiplier;
}

({double? used, double? total}) _parseBytePair(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return (used: null, total: null);
  final parts = trimmed.split('/');
  if (parts.isEmpty) return (used: null, total: null);
  final used = _parseByte(parts.first);
  final total = parts.length > 1 ? _parseByte(parts[1]) : null;
  return (used: used, total: total);
}

double? _parseBytePairTotal(String raw) {
  final parsed = _parseBytePair(raw);
  final used = parsed.used;
  final total = parsed.total;
  if (used == null && total == null) return null;
  return (used ?? 0) + (total ?? 0);
}

Object? _readPorts(Map<dynamic, dynamic> json, String key) {
  return json['ports'] ?? json['Ports'];
}

Object? _readPortIp(Map<dynamic, dynamic> json, String key) {
  return json['ip'] ?? json['IP'];
}

Object? _readPortPrivate(Map<dynamic, dynamic> json, String key) {
  return json['private_port'] ?? json['PrivatePort'] ?? json['privatePort'];
}

Object? _readPortPublic(Map<dynamic, dynamic> json, String key) {
  return json['public_port'] ?? json['PublicPort'] ?? json['publicPort'];
}

Object? _readPortType(Map<dynamic, dynamic> json, String key) {
  return json['typ'] ?? json['type'] ?? json['Type'];
}
