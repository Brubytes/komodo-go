import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/fake_komodo_backend.dart';

void registerProceduresRunTests() {
  patrolTest('login → procedures → run procedure (fake backend)', ($) async {
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

      await $(find.byKey(const ValueKey('resources_stat_procedures')))
          .waitUntilVisible();
      await $(find.byKey(const ValueKey('resources_stat_procedures'))).tap();

      await $(find.text('Test Procedure')).waitUntilVisible();
      await $(find.byKey(const ValueKey('procedure_card_run_procedure-1')))
          .tap();
      await $.pumpAndSettle();

      final runCalls = backend.calls
          .where((c) => c.path == '/execute' && c.type == 'RunProcedure')
          .toList();
      expect(runCalls.length, 1);
    } finally {
      await backend.stop();
    }
  });
}

void main() => registerProceduresRunTests();
