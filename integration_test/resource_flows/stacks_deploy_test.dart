import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerStacksDeployTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'login → stacks → detail → redeploy (fake backend)',
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

        // Open Stacks list
        await $(
          find.byKey(const ValueKey('resources_stat_stacks')),
        ).waitUntilVisible();
        await $(find.byKey(const ValueKey('resources_stat_stacks'))).tap();

        // Tap on the stack to open detail view
        final stackName = config.isFake ? 'Test Stack' : config.stackName;
        await $(find.text(stackName)).waitUntilVisible();
        await $(find.text(stackName)).tap();

        // Open popup menu and tap Redeploy
        await $(find.byIcon(AppIcons.moreVertical)).waitUntilVisible();
        await $(find.byIcon(AppIcons.moreVertical)).tap();
        await $(find.text('Redeploy')).tap();
        await $.pumpAndSettle();

        if (backend.isFake) {
          final deployCalls = backend.fake!.calls
              .where((c) => c.path == '/execute' && c.type == 'DeployStack')
              .toList();
          expect(deployCalls.length, 1);
        }
      } finally {
        await backend.stop();
      }
    },
    skip:
        config.skipReason(
          requiredResourceLabel: 'KOMODO_TEST_STACK_NAME',
          requiredResourceValue: config.stackName,
        ) !=
        null,
  );
}

void main() => registerStacksDeployTests();
