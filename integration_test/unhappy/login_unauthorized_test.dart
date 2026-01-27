import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/fake_komodo_backend.dart';

void registerLoginUnauthorizedTests() {
  patrolTest('unhappy: invalid credentials show auth error', ($) async {
    final backend = FakeKomodoBackend(
      expectedApiKey: 'test-key',
      expectedApiSecret: 'test-secret',
      port: 57868,
    );
    await backend.start();
    backend.queueError(
      path: '/read',
      type: 'GetVersion',
      statusCode: 401,
      message: 'Unauthorized',
    );
    backend.queueError(
      path: '/read',
      type: 'GetVersion',
      statusCode: 401,
      message: 'Unauthorized',
    );

    try {
      await app.main();
      await $.pumpAndSettle();

      await ensureOnLoginAddForm($);
      await $(find.byKey(const Key('login_serverUrl'))).enterText(
        backend.baseUrl,
      );
      await $(find.byKey(const Key('login_apiKey'))).enterText('test-key');
      await $(find.byKey(const Key('login_apiSecret'))).enterText('test-secret');
      await $(find.byKey(const Key('login_saveConnection'))).tap();

      await $(find.text('Invalid API credentials')).waitUntilVisible();
    } finally {
      await backend.stop();
    }
  });
}

void main() => registerLoginUnauthorizedTests();
