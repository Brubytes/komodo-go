import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/proxy_auth.dart';

void main() {
  group('ProxyAuthConfig.headers', () {
    test('uses Authorization for basic auth', () {
      final config = ProxyAuthConfig(
        scheme: ProxyAuthScheme.basic,
        username: 'user',
        password: 'pass',
      );

      final headers = config.headers();

      expect(headers.keys, hasLength(1));
      expect(
        headers['Authorization'],
        equals('Basic ${base64Encode(utf8.encode('user:pass'))}'),
      );
    });

    test('returns empty map when credentials are incomplete', () {
      final config = ProxyAuthConfig(
        scheme: ProxyAuthScheme.basic,
        username: 'user',
        password: '   ',
      );

      expect(config.headers(), isEmpty);
    });

    test('returns empty map when auth is disabled', () {
      final config = ProxyAuthConfig(
        scheme: ProxyAuthScheme.basic,
        username: 'user',
        password: 'pass',
        enabled: false,
      );

      expect(config.shouldApply, isFalse);
      expect(config.headers(), isEmpty);
    });
  });
}
