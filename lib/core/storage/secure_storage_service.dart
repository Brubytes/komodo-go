import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Credentials for authenticating with the Komodo API.
class ApiCredentials {
  const ApiCredentials({
    required this.baseUrl,
    required this.apiKey,
    required this.apiSecret,
  });

  final String baseUrl;
  final String apiKey;
  final String apiSecret;
}

/// Service for securely storing sensitive data like API credentials.
class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  static const _baseUrlKey = 'komodo_base_url';
  static const _apiKeyKey = 'komodo_api_key';
  static const _apiSecretKey = 'komodo_api_secret';

  /// Saves API credentials to secure storage.
  Future<void> saveCredentials(ApiCredentials credentials) async {
    await Future.wait([
      _storage.write(key: _baseUrlKey, value: credentials.baseUrl),
      _storage.write(key: _apiKeyKey, value: credentials.apiKey),
      _storage.write(key: _apiSecretKey, value: credentials.apiSecret),
    ]);
  }

  /// Retrieves stored API credentials.
  /// Returns null if credentials are not stored.
  Future<ApiCredentials?> getCredentials() async {
    final results = await Future.wait([
      _storage.read(key: _baseUrlKey),
      _storage.read(key: _apiKeyKey),
      _storage.read(key: _apiSecretKey),
    ]);

    final baseUrl = results[0];
    final apiKey = results[1];
    final apiSecret = results[2];

    if (baseUrl == null || apiKey == null || apiSecret == null) {
      return null;
    }

    return ApiCredentials(
      baseUrl: baseUrl,
      apiKey: apiKey,
      apiSecret: apiSecret,
    );
  }

  /// Gets just the base URL without the full credentials.
  Future<String?> getBaseUrl() async {
    return _storage.read(key: _baseUrlKey);
  }

  /// Clears all stored credentials.
  Future<void> clearCredentials() async {
    await Future.wait([
      _storage.delete(key: _baseUrlKey),
      _storage.delete(key: _apiKeyKey),
      _storage.delete(key: _apiSecretKey),
    ]);
  }

  /// Checks if credentials are stored.
  Future<bool> hasCredentials() async {
    final credentials = await getCredentials();
    return credentials != null;
  }
}
