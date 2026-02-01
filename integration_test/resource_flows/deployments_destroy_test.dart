import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerDeploymentsDestroyTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'login → deployments → destroy deployment (fake backend)',
    ($) async {
      final backend = await PatrolTestBackend.start(config);

      try {
        await app.main();
        await $.pumpAndSettle();

        await loginWith(
          $,
          baseUrl: backend.baseUrl,
          apiKey: backend.apiKey,
          apiSecret: backend.apiSecret,
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

        final deploymentName =
            config.isFake ? 'Test Deployment' : config.deploymentName;
        await $(find.text(deploymentName)).waitUntilVisible();

        if (config.isFake) {
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
        } else {
          await $(find.text(deploymentName)).tap();
          await $(find.byIcon(AppIcons.moreVertical)).tap();
          await $(find.text('Destroy')).tap();
          await $(find.text('Destroy')).tap();
        }

        await $.pumpAndSettle();

        if (backend.isFake) {
          // Deployment should be gone after destroy.
          expect(find.text('Test Deployment'), findsNothing);

          final destroyCalls = backend.fake!.calls
              .where((c) => c.path == '/execute' && c.type == 'DestroyDeployment')
              .toList();
          expect(destroyCalls.length, 1);
        }
      } finally {
        await backend.stop();
      }
    },
    skip: config.skipReason(
      requiresDestructive: true,
      requiredResourceLabel: 'KOMODO_TEST_DEPLOYMENT_NAME',
      requiredResourceValue: config.deploymentName,
    ) != null,
  );
}

void main() => registerDeploymentsDestroyTests();
