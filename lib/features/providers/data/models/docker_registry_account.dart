import 'package:freezed_annotation/freezed_annotation.dart';

part 'docker_registry_account.freezed.dart';
part 'docker_registry_account.g.dart';

@freezed
sealed class DockerRegistryAccount with _$DockerRegistryAccount {
  const factory DockerRegistryAccount({
    @JsonKey(readValue: _readId) required String id,
    required String domain,
    required String username,
    @Default('') String token,
  }) = _DockerRegistryAccount;

  factory DockerRegistryAccount.fromJson(Map<String, dynamic> json) =>
      _$DockerRegistryAccountFromJson(json);
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
