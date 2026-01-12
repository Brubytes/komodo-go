import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/fake_komodo_backend.dart';

void registerDeploymentsDestroyTests() {
  patrolTest('login → deployments → destroy deployment (fake backend)', ($) async {
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

      // Ensure we're on the Resources tab (the text "Resources" may also exist
      // as an app bar title on other routes).
      await $(find.byKey(const ValueKey('bottom_nav_resources')))
          .waitUntilVisible();
      await $(find.byKey(const ValueKey('bottom_nav_resources'))).tap();
      await $.pumpAndSettle();

      // Use a stable selector for the Deployments stat card.
      await $(find.byKey(const ValueKey('resources_stat_deployments')))
          .waitUntilVisible();
      await $(find.byKey(const ValueKey('resources_stat_deployments'))).tap();

      await $(find.text('Test Deployment')).waitUntilVisible();

      // Open overflow menu for the seeded deployment card.
      await $(
        find.byKey(const ValueKey('deployment_card_menu_deployment-1')),
      ).tap();

      await $(
        find.byKey(const ValueKey('deployment_card_destroy_deployment-1')),
      ).tap();

      await $(
        find.byKey(const ValueKey('deployment_destroy_confirm_deployment-1')),
      ).tap();

      await $.pumpAndSettle();

      // Deployment should be gone after destroy.
      expect(find.text('Test Deployment'), findsNothing);

      final destroyCalls = backend.calls
          .where((c) => c.path == '/execute' && c.type == 'DestroyDeployment')
          .toList();
      expect(destroyCalls.length, 1);
    } finally {
      await backend.stop();
    }
  });
}

void main() => registerDeploymentsDestroyTests();
