import 'dart:convert';

/// Non-sensitive connection metadata (safe to store in SharedPreferences).
class ConnectionProfile {
  const ConnectionProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.createdAt,
    required this.lastUsedAt,
  });

  final String id;
  final String name;
  final String baseUrl;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  ConnectionProfile copyWith({
    String? id,
    String? name,
    String? baseUrl,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return ConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'createdAt': createdAt.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
  };

  static ConnectionProfile fromJson(Map<String, dynamic> json) {
    return ConnectionProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: (json['lastUsedAt'] as String?) == null
          ? null
          : DateTime.parse(json['lastUsedAt'] as String),
    );
  }
}

String encodeConnectionProfiles(List<ConnectionProfile> profiles) {
  return jsonEncode(profiles.map((p) => p.toJson()).toList());
}

List<ConnectionProfile> decodeConnectionProfiles(String raw) {
  final decoded = jsonDecode(raw) as List<dynamic>;
  return decoded
      .map((e) => ConnectionProfile.fromJson(e as Map<String, dynamic>))
      .toList();
}
