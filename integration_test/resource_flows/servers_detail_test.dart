import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/fake_komodo_backend.dart';

void registerServersDetailTests() {
  patrolTest('login → servers → detail stats + system (fake backend)', (
    $,
  ) async {
    final backend = FakeKomodoBackend(
      expectedApiKey: 'test-key',
      expectedApiSecret: 'test-secret',
      port: 57868,
    );
    await backend.start();

    try {
      await app.main();
      await $.pumpAndSettle();

      await loginWith(
        $,
        baseUrl: backend.baseUrl,
        apiKey: 'test-key',
        apiSecret: 'test-secret',
      );

      await $(find.byKey(const ValueKey('bottom_nav_resources')))
          .waitUntilVisible();
      await $(find.byKey(const ValueKey('bottom_nav_resources'))).tap();

      await $(find.byKey(const ValueKey('resources_stat_servers')))
          .waitUntilVisible();
      await $(find.byKey(const ValueKey('resources_stat_servers'))).tap();

      await $(find.text('Test Server')).waitUntilVisible();
      await $(find.byKey(const ValueKey('server_card_server-1'))).tap();

      await $(find.text('Stats')).tap();
      await $(find.text('Scale')).scrollTo();
      await $(find.text('Scale')).waitUntilVisible();

      await $(find.text('System')).tap();
      await $(find.text('Basics')).waitUntilVisible();

      final statsCalls = backend.calls
          .where((c) => c.path == '/read' && c.type == 'GetSystemStats')
          .toList();
      expect(statsCalls, isNotEmpty);

      final systemCalls = backend.calls
          .where((c) => c.path == '/read' && c.type == 'GetSystemInformation')
          .toList();
      expect(systemCalls, isNotEmpty);
    } finally {
      await backend.stop();
    }
  });
}

void main() => registerServersDetailTests();
