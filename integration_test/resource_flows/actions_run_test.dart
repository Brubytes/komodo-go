import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerActionsRunTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'login → actions → run action (fake backend)',
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

        await $(find.byKey(const ValueKey('bottom_nav_resources')))
            .waitUntilVisible();
        await $(find.byKey(const ValueKey('bottom_nav_resources'))).tap();

        await $(find.byKey(const ValueKey('resources_stat_actions')))
            .waitUntilVisible();
        await $(find.byKey(const ValueKey('resources_stat_actions'))).tap();

        final actionName = config.isFake ? 'Test Action' : config.actionName;
        await $(find.text(actionName)).waitUntilVisible();
        await $(find.text(actionName)).tap();
        await $(find.byIcon(AppIcons.play)).tap();
        await $.pumpAndSettle();

        if (backend.isFake) {
          final runCalls = backend.fake!.calls
              .where((c) => c.path == '/execute' && c.type == 'RunAction')
              .toList();
          expect(runCalls.length, 1);
        }
      } finally {
        await backend.stop();
      }
    },
    skip: config.skipReason(
      requiredResourceLabel: 'KOMODO_TEST_ACTION_NAME',
      requiredResourceValue: config.actionName,
    ) != null,
  );
}

void main() => registerActionsRunTests();
