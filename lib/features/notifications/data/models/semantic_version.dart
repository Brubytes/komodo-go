class SemanticVersion {
  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
  });

  final int major;
  final int minor;
  final int patch;

  factory SemanticVersion.fromJson(Object? json) {
    if (json is Map<String, dynamic>) {
      return SemanticVersion(
        major: _readInt(json['major']),
        minor: _readInt(json['minor']),
        patch: _readInt(json['patch']),
      );
    }
    if (json is Map) {
      return SemanticVersion(
        major: _readInt(json['major']),
        minor: _readInt(json['minor']),
        patch: _readInt(json['patch']),
      );
    }
    return const SemanticVersion(major: 0, minor: 0, patch: 0);
  }

  String get label => '$major.$minor.$patch';
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
