import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/fake_komodo_backend.dart';

void registerBuildsRunCancelTests() {
  patrolTest('login → builds → run + cancel build (fake backend)', ($) async {
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

      await $(find.byKey(const ValueKey('resources_stat_builds')))
          .waitUntilVisible();
      await $(find.byKey(const ValueKey('resources_stat_builds'))).tap();

      await $(find.text('Test Build')).waitUntilVisible();

      await $(find.byKey(const ValueKey('build_card_menu_build-1'))).tap();
      await $(find.byKey(const ValueKey('build_card_run_build-1'))).tap();
      await $(find.text('Action completed successfully')).waitUntilVisible();
      await $.pumpAndSettle();

      await $(find.byKey(const ValueKey('build_card_menu_build-1'))).tap();
      await $(find.byKey(const ValueKey('build_card_cancel_build-1')))
          .waitUntilVisible();
      await $(find.byKey(const ValueKey('build_card_cancel_build-1'))).tap();
      await $(find.text('Action completed successfully')).waitUntilVisible();

      final runCalls = backend.calls
          .where((c) => c.path == '/execute' && c.type == 'RunBuild')
          .toList();
      expect(runCalls.length, 1);

      final cancelCalls = backend.calls
          .where((c) => c.path == '/execute' && c.type == 'CancelBuild')
          .toList();
      expect(cancelCalls.length, 1);
    } finally {
      await backend.stop();
    }
  });
}

void main() => registerBuildsRunCancelTests();
