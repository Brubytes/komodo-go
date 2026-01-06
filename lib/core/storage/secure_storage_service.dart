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

  static String _baseUrlKey(String connectionId) =>
      'komodo/$connectionId/base_url';
  static String _apiKeyKey(String connectionId) =>
      'komodo/$connectionId/api_key';
  static String _apiSecretKey(String connectionId) =>
      'komodo/$connectionId/api_secret';

  /// Saves API credentials for a specific connection.
  Future<void> saveCredentialsForConnection({
    required String connectionId,
    required ApiCredentials credentials,
  }) async {
    await Future.wait([
      _storage.write(
        key: _baseUrlKey(connectionId),
        value: credentials.baseUrl,
      ),
      _storage.write(key: _apiKeyKey(connectionId), value: credentials.apiKey),
      _storage.write(
        key: _apiSecretKey(connectionId),
        value: credentials.apiSecret,
      ),
    ]);
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

  /// Deletes credentials for a specific connection.
  Future<void> deleteCredentialsForConnection(String connectionId) async {
    await Future.wait([
      _storage.delete(key: _baseUrlKey(connectionId)),
      _storage.delete(key: _apiKeyKey(connectionId)),
      _storage.delete(key: _apiSecretKey(connectionId)),
    ]);
  }
}
