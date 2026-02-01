import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerProceduresRunTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'login → procedures → run procedure (fake backend)',
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

        await $(find.byKey(const ValueKey('resources_stat_procedures')))
            .waitUntilVisible();
        await $(find.byKey(const ValueKey('resources_stat_procedures'))).tap();

        final procedureName =
            config.isFake ? 'Test Procedure' : config.procedureName;
        await $(find.text(procedureName)).waitUntilVisible();
        await $(find.text(procedureName)).tap();
        await $(find.byIcon(AppIcons.play)).tap();
        await $.pumpAndSettle();

        if (backend.isFake) {
          final runCalls = backend.fake!.calls
              .where((c) => c.path == '/execute' && c.type == 'RunProcedure')
              .toList();
          expect(runCalls.length, 1);
        }
      } finally {
        await backend.stop();
      }
    },
    skip: config.skipReason(
      requiredResourceLabel: 'KOMODO_TEST_PROCEDURE_NAME',
      requiredResourceValue: config.procedureName,
    ) != null,
  );
}

void main() => registerProceduresRunTests();
