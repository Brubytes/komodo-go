import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/fake_komodo_backend.dart';

void registerActionsRunTests() {
  patrolTest('login → actions → run action (fake backend)', ($) async {
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

      await $(find.byKey(const ValueKey('resources_stat_actions')))
          .waitUntilVisible();
      await $(find.byKey(const ValueKey('resources_stat_actions'))).tap();

      await $(find.text('Test Action')).waitUntilVisible();
      await $(find.byKey(const ValueKey('action_card_run_action-1'))).tap();
      await $.pumpAndSettle();

      final runCalls = backend.calls
          .where((c) => c.path == '/execute' && c.type == 'RunAction')
          .toList();
      expect(runCalls.length, 1);
    } finally {
      await backend.stop();
    }
  });
}

void main() => registerActionsRunTests();
