import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  static const _duplicateItemStatus = -25299;
  static const _migrationIOSOptions = IOSOptions(accessibility: null);
  static const _migrationMacOSOptions = MacOsOptions(accessibility: null);

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
      _writeValue(
        key: _baseUrlKey(connectionId),
        value: credentials.baseUrl,
      ),
      _writeValue(key: _apiKeyKey(connectionId), value: credentials.apiKey),
      _writeValue(
        key: _apiSecretKey(connectionId),
        value: credentials.apiSecret,
      ),
      if (credentials.proxyAuth case final proxyAuth? when proxyAuth.isComplete)
        _writeValue(
          key: _proxyAuthSchemeKey(connectionId),
          value: proxyAuth.scheme.toStorageValue,
        )
      else
        _storage.delete(key: _proxyAuthSchemeKey(connectionId)),
      if (credentials.proxyAuth case final proxyAuth? when proxyAuth.isComplete)
        _writeValue(
          key: _proxyAuthEnabledKey(connectionId),
          value: proxyAuth.enabled.toString(),
        )
      else
        _storage.delete(key: _proxyAuthEnabledKey(connectionId)),
      if (credentials.proxyAuth case final proxyAuth? when proxyAuth.isComplete)
        _writeValue(
          key: _proxyAuthUsernameKey(connectionId),
          value: proxyAuth.username,
        )
      else
        _storage.delete(key: _proxyAuthUsernameKey(connectionId)),
      if (credentials.proxyAuth case final proxyAuth? when proxyAuth.isComplete)
        _writeValue(
          key: _proxyAuthPasswordKey(connectionId),
          value: proxyAuth.password,
        )
      else
        _storage.delete(key: _proxyAuthPasswordKey(connectionId)),
      if (customHeaders.isNotEmpty)
        _writeValue(
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
      _readValue(_baseUrlKey(connectionId)),
      _readValue(_apiKeyKey(connectionId)),
      _readValue(_apiSecretKey(connectionId)),
      _readValue(_proxyAuthSchemeKey(connectionId)),
      _readValue(_proxyAuthEnabledKey(connectionId)),
      _readValue(_proxyAuthUsernameKey(connectionId)),
      _readValue(_proxyAuthPasswordKey(connectionId)),
      _readValue(_customHeadersKey(connectionId)),
    ]);

    final baseUrl = results[0];
    final apiKey = results[1];
    final apiSecret = results[2];
    final proxyAuthScheme = ProxyAuthSchemeX.fromStorage(results[3]);
    final proxyAuthEnabled = results[4] == null || results[4] == 'true';
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

  Future<String?> _readValue(String key) async {
    final value = await _storage.read(key: key);
    if (value != null || !_usesAppleKeychain) {
      return value;
    }

    // flutter_secure_storage_darwin 0.2.x created items with an empty
    // kSecAttrAccessControl. Version 0.3.x searches using kSecAttrAccessible
    // instead, so an in-place app upgrade can no longer find those items.
    // Omitting both attributes searches by the stable generic-password
    // identity (account/service/synchronizable) and reads either format.
    return _storage.read(
      key: key,
      iOptions: _migrationIOSOptions,
      mOptions: _migrationMacOSOptions,
    );
  }

  Future<void> _writeValue({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (error) {
      if (!_usesAppleKeychain || !_isDuplicateItem(error)) {
        rethrow;
      }

      // A legacy item can be invisible to the plugin's new existence query
      // while still sharing the same Keychain primary key. The user is
      // explicitly replacing this value, so remove the primary-key match and
      // retry using the current accessibility format.
      await _storage.delete(
        key: key,
        iOptions: _migrationIOSOptions,
        mOptions: _migrationMacOSOptions,
      );
      await _storage.write(key: key, value: value);
    }
  }

  bool _isDuplicateItem(PlatformException error) {
    return error.details == _duplicateItemStatus ||
        error.code == '$_duplicateItemStatus' ||
        (error.message?.contains('$_duplicateItemStatus') ?? false);
  }

  bool get _usesAppleKeychain =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
}
