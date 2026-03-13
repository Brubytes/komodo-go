import 'dart:convert';

enum ProxyAuthScheme { basic }

extension ProxyAuthSchemeX on ProxyAuthScheme {
  String get toStorageValue => switch (this) {
    ProxyAuthScheme.basic => 'basic',
  };

  static ProxyAuthScheme? fromStorage(String? value) {
    return switch (value) {
      'basic' => ProxyAuthScheme.basic,
      _ => null,
    };
  }
}

class ProxyAuthConfig {
  const ProxyAuthConfig({
    required this.scheme,
    required this.username,
    required this.password,
    this.enabled = true,
  });

  final ProxyAuthScheme scheme;
  final String username;
  final String password;
  final bool enabled;

  bool get isComplete {
    return username.trim().isNotEmpty && password.trim().isNotEmpty;
  }

  bool get shouldApply => enabled && isComplete;

  Map<String, String> headers() {
    if (!shouldApply) {
      return const <String, String>{};
    }

    return switch (scheme) {
      ProxyAuthScheme.basic => <String, String>{
        'Authorization':
            'Basic ${base64Encode(utf8.encode('${username.trim()}:${password.trim()}'))}',
      },
    };
  }
}
