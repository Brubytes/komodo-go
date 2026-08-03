import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockFlutterSecureStorage storage;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    storage = _MockFlutterSecureStorage();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'reads credentials written with the legacy Darwin query format',
    () async {
      const connectionId = 'legacy';
      final legacyValues = <String, String>{
        'komodo/$connectionId/base_url': 'https://komodo.example',
        'komodo/$connectionId/api_key': 'legacy-key',
        'komodo/$connectionId/api_secret': 'legacy-secret',
      };

      when(() => storage.read(key: any(named: 'key'))).thenAnswer(
        (_) async => null,
      );
      when(
        () => storage.read(
          key: any(named: 'key'),
          iOptions: any(named: 'iOptions'),
          mOptions: any(named: 'mOptions'),
        ),
      ).thenAnswer((invocation) async {
        final options = invocation.namedArguments[#iOptions] as IOSOptions?;
        if (options == null) {
          return null;
        }
        expect(options.accessibility, isNull);
        return legacyValues[invocation.namedArguments[#key] as String];
      });

      final credentials = await SecureStorageService(
        storage,
      ).getCredentialsForConnection(connectionId);

      expect(credentials, isNotNull);
      expect(credentials?.baseUrl, 'https://komodo.example');
      expect(credentials?.apiKey, 'legacy-key');
      expect(credentials?.apiSecret, 'legacy-secret');
    },
  );

  test('replaces a legacy item when Keychain reports a duplicate', () async {
    const connectionId = 'legacy';
    final deletedKeys = <String>{};
    final savedValues = <String, String>{};

    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key]! as String;
      if (!deletedKeys.contains(key)) {
        throw PlatformException(
          code: 'Unexpected security result code',
          message:
              'Code: -25299, Message: The specified item already exists in the keychain.',
          details: -25299,
        );
      }
      savedValues[key] = invocation.namedArguments[#value]! as String;
    });
    when(
      () => storage.delete(
        key: any(named: 'key'),
        iOptions: any(named: 'iOptions'),
        mOptions: any(named: 'mOptions'),
      ),
    ).thenAnswer((invocation) async {
      deletedKeys.add(invocation.namedArguments[#key]! as String);
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer(
      (_) async {},
    );

    await SecureStorageService(storage).saveCredentialsForConnection(
      connectionId: connectionId,
      credentials: const ApiCredentials(
        baseUrl: 'https://komodo.example',
        apiKey: 'replacement-key',
        apiSecret: 'replacement-secret',
      ),
    );

    expect(
      savedValues,
      containsPair(
        'komodo/$connectionId/base_url',
        'https://komodo.example',
      ),
    );
    expect(
      savedValues,
      containsPair('komodo/$connectionId/api_key', 'replacement-key'),
    );
    expect(
      savedValues,
      containsPair('komodo/$connectionId/api_secret', 'replacement-secret'),
    );
  });
}
