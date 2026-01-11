import 'package:freezed_annotation/freezed_annotation.dart';

part 'git_provider_account.freezed.dart';
part 'git_provider_account.g.dart';

@freezed
sealed class GitProviderAccount with _$GitProviderAccount {
  const factory GitProviderAccount({
    @JsonKey(readValue: _readId) required String id,
    required String domain,
    required String username, @Default(true) bool https,
    @Default('') String token,
  }) = _GitProviderAccount;

  factory GitProviderAccount.fromJson(Map<String, dynamic> json) =>
      _$GitProviderAccountFromJson(json);
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
