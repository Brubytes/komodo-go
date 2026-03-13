import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:komodo_go/core/api/custom_header.dart';
import 'package:komodo_go/core/api/proxy_auth.dart';

/// Credentials for authenticating with the Komodo API.
class ApiCredentials {
  const ApiCredentials({
    required this.baseUrl,
    required this.apiKey,
    required this.apiSecret,
    this.proxyAuth,
    this.customHeaders = const [],
  });

  final String baseUrl;
  final String apiKey;
  final String apiSecret;
  final ProxyAuthConfig? proxyAuth;
  final List<CustomHeader> customHeaders;

  Map<String, String> additionalHeaders() {
    final headers = <String, String>{};
    final proxyAuth = this.proxyAuth;
    if (proxyAuth != null) {
      headers.addAll(proxyAuth.headers());
    }
    for (final header in sanitizeCustomHeaders(customHeaders)) {
      headers[header.trimmedKey] = header.trimmedValue;
    }
    return headers;
  }
}

/// Service for securely storing sensitive data like API credentials.
class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  static String _baseUrlKey(String connectionId) =>
      'komodo/$connectionId/base_url';
  static String _apiKeyKey(String connectionId) =>
      'komodo/$connectionId/api_key';
  static String _apiSecretKey(String connectionId) =>
      'komodo/$connectionId/api_secret';
  static String _proxyAuthSchemeKey(String connectionId) =>
      'komodo/$connectionId/proxy_auth_scheme';
  static String _proxyAuthEnabledKey(String connectionId) =>
      'komodo/$connectionId/proxy_auth_enabled';
  static String _proxyAuthUsernameKey(String connectionId) =>
      'komodo/$connectionId/proxy_auth_username';
  static String _proxyAuthPasswordKey(String connectionId) =>
      'komodo/$connectionId/proxy_auth_password';
  static String _customHeadersKey(String connectionId) =>
      'komodo/$connectionId/custom_headers_json';

  /// Saves API credentials for a specific connection.
  Future<void> saveCredentialsForConnection({
    required String connectionId,
    required ApiCredentials credentials,
  }) async {
    final customHeaders = sanitizeCustomHeaders(credentials.customHeaders);
    final writes = <Future<void>>[
      _storage.write(
        key: _baseUrlKey(connectionId),
        value: credentials.baseUrl,
      ),
      _storage.write(key: _apiKeyKey(connectionId), value: credentials.apiKey),
      _storage.write(
        key: _apiSecretKey(connectionId),
        value: credentials.apiSecret,
      ),
      if (credentials.proxyAuth case final proxyAuth? when proxyAuth.isComplete)
        _storage.write(
          key: _proxyAuthSchemeKey(connectionId),
          value: proxyAuth.scheme.toStorageValue,
        )
      else
        _storage.delete(key: _proxyAuthSchemeKey(connectionId)),
      if (credentials.proxyAuth case final proxyAuth? when proxyAuth.isComplete)
        _storage.write(
          key: _proxyAuthEnabledKey(connectionId),
          value: proxyAuth.enabled.toString(),
        )
      else
        _storage.delete(key: _proxyAuthEnabledKey(connectionId)),
      if (credentials.proxyAuth case final proxyAuth? when proxyAuth.isComplete)
        _storage.write(
          key: _proxyAuthUsernameKey(connectionId),
          value: proxyAuth.username,
        )
      else
        _storage.delete(key: _proxyAuthUsernameKey(connectionId)),
      if (credentials.proxyAuth case final proxyAuth? when proxyAuth.isComplete)
        _storage.write(
          key: _proxyAuthPasswordKey(connectionId),
          value: proxyAuth.password,
        )
      else
        _storage.delete(key: _proxyAuthPasswordKey(connectionId)),
      if (customHeaders.isNotEmpty)
        _storage.write(
          key: _customHeadersKey(connectionId),
          value: jsonEncode(
            customHeaders.map((header) => header.toJson()).toList(),
          ),
        )
      else
        _storage.delete(key: _customHeadersKey(connectionId)),
    ];

    await Future.wait(writes);
  }

  /// Retrieves stored API credentials for a specific connection.
  /// Returns null if credentials are not stored.
  Future<ApiCredentials?> getCredentialsForConnection(
    String connectionId,
  ) async {
    final results = await Future.wait([
      _storage.read(key: _baseUrlKey(connectionId)),
      _storage.read(key: _apiKeyKey(connectionId)),
      _storage.read(key: _apiSecretKey(connectionId)),
      _storage.read(key: _proxyAuthSchemeKey(connectionId)),
      _storage.read(key: _proxyAuthEnabledKey(connectionId)),
      _storage.read(key: _proxyAuthUsernameKey(connectionId)),
      _storage.read(key: _proxyAuthPasswordKey(connectionId)),
      _storage.read(key: _customHeadersKey(connectionId)),
    ]);

    final baseUrl = results[0];
    final apiKey = results[1];
    final apiSecret = results[2];
    final proxyAuthScheme = ProxyAuthSchemeX.fromStorage(results[3]);
    final proxyAuthEnabled = results[4] == null ? true : results[4] == 'true';
    final proxyAuthUsername = results[5]?.trim();
    final proxyAuthPassword = results[6]?.trim();
    final customHeaders = _decodeCustomHeaders(results[7]);

    if (baseUrl == null || apiKey == null || apiSecret == null) {
      return null;
    }

    final proxyAuth = switch ((
      proxyAuthScheme,
      proxyAuthUsername,
      proxyAuthPassword,
    )) {
      (final scheme?, final username?, final password?)
          when username.isNotEmpty && password.isNotEmpty =>
        ProxyAuthConfig(
          scheme: scheme,
          username: username,
          password: password,
          enabled: proxyAuthEnabled,
        ),
      _ => null,
    };

    return ApiCredentials(
      baseUrl: baseUrl,
      apiKey: apiKey,
      apiSecret: apiSecret,
      proxyAuth: proxyAuth,
      customHeaders: customHeaders,
    );
  }

  /// Deletes credentials for a specific connection.
  Future<void> deleteCredentialsForConnection(String connectionId) async {
    await Future.wait([
      _storage.delete(key: _baseUrlKey(connectionId)),
      _storage.delete(key: _apiKeyKey(connectionId)),
      _storage.delete(key: _apiSecretKey(connectionId)),
      _storage.delete(key: _proxyAuthSchemeKey(connectionId)),
      _storage.delete(key: _proxyAuthEnabledKey(connectionId)),
      _storage.delete(key: _proxyAuthUsernameKey(connectionId)),
      _storage.delete(key: _proxyAuthPasswordKey(connectionId)),
      _storage.delete(key: _customHeadersKey(connectionId)),
    ]);
  }

  List<CustomHeader> _decodeCustomHeaders(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      return sanitizeCustomHeaders(
        decoded.whereType<Map<dynamic, dynamic>>().map(
          (item) => CustomHeader.fromJson(
            item.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        ),
      );
    } on FormatException {
      return const [];
    }
  }
}
