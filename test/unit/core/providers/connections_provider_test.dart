import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/custom_header.dart';
import 'package:komodo_go/core/api/proxy_auth.dart';
import 'package:komodo_go/core/providers/connections_provider.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';

void main() {
  group('mergeConnectionCredentialsForUpdate', () {
    const currentCredentials = ApiCredentials(
      baseUrl: 'https://komodo.example.com',
      apiKey: 'key',
      apiSecret: 'secret',
      proxyAuth: ProxyAuthConfig(
        scheme: ProxyAuthScheme.basic,
        username: 'proxy-user',
        password: 'proxy-pass',
      ),
      customHeaders: [CustomHeader(key: 'X-Test', value: 'one')],
    );

    test('preserves proxy auth when unrelated fields change', () {
      final updated = mergeConnectionCredentialsForUpdate(
        currentCredentials: currentCredentials,
        baseUrl: 'https://komodo.example.com',
        apiKey: 'new-key',
      );

      expect(updated.apiKey, 'new-key');
      expect(updated.proxyAuth, isNotNull);
      expect(updated.proxyAuth?.username, 'proxy-user');
      expect(updated.proxyAuth?.password, 'proxy-pass');
      expect(updated.proxyAuth?.enabled, isTrue);
      expect(updated.customHeaders, currentCredentials.customHeaders);
    });

    test('preserves stored proxy credentials when only enabled changes', () {
      final updated = mergeConnectionCredentialsForUpdate(
        currentCredentials: currentCredentials,
        baseUrl: 'https://komodo.example.com',
        proxyAuthEnabled: false,
      );

      expect(updated.proxyAuth, isNotNull);
      expect(updated.proxyAuth?.username, 'proxy-user');
      expect(updated.proxyAuth?.password, 'proxy-pass');
      expect(updated.proxyAuth?.enabled, isFalse);
    });

    test('clears proxy auth when both fields are explicitly blanked', () {
      final updated = mergeConnectionCredentialsForUpdate(
        currentCredentials: currentCredentials,
        baseUrl: 'https://komodo.example.com',
        proxyAuthUsername: '',
        proxyAuthPassword: '',
      );

      expect(updated.proxyAuth, isNull);
    });
  });
}
