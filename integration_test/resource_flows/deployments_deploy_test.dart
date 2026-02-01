import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerDeploymentsDeployTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'login → deployments → detail → deploy (fake backend)',
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

        // Navigate to Resources
        await $(
          find.byKey(const ValueKey('bottom_nav_resources')),
        ).waitUntilVisible();
        await $(find.byKey(const ValueKey('bottom_nav_resources'))).tap();

        // Open Deployments list
        await $(
          find.byKey(const ValueKey('resources_stat_deployments')),
        ).waitUntilVisible();
        await $(find.byKey(const ValueKey('resources_stat_deployments'))).tap();

        // Tap on the deployment to open detail view
        final deploymentName = config.isFake
            ? 'Test Deployment'
            : config.deploymentName;
        await $(find.text(deploymentName)).waitUntilVisible();
        await $(find.text(deploymentName)).tap();

        // Open popup menu and tap Deploy/Redeploy
        await $(find.byIcon(AppIcons.moreVertical)).waitUntilVisible();
        await $(find.byIcon(AppIcons.moreVertical)).tap();
        // The label is 'Redeploy' for running deployments, 'Deploy' for not deployed
        await $(find.text('Redeploy')).waitUntilVisible();
        await $(find.text('Redeploy')).tap();
        await $.pumpAndSettle();

        if (backend.isFake) {
          final deployCalls = backend.fake!.calls
              .where((c) => c.path == '/execute' && c.type == 'Deploy')
              .toList();
          expect(deployCalls.length, 1);
        }
      } finally {
        await backend.stop();
      }
    },
    skip:
        config.skipReason(
          requiredResourceLabel: 'KOMODO_TEST_DEPLOYMENT_NAME',
          requiredResourceValue: config.deploymentName,
        ) !=
        null,
  );
}

void main() => registerDeploymentsDeployTests();
