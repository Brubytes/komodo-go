import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerSyncsRunTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'login → syncs → run sync (fake backend)',
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

        // Open Syncs list
        await $(
          find.byKey(const ValueKey('resources_stat_syncs')),
        ).waitUntilVisible();
        await $(find.byKey(const ValueKey('resources_stat_syncs'))).tap();

        // Wait for sync card
        final syncName = config.isFake ? 'Test Sync' : config.syncName;
        await $(find.text(syncName)).waitUntilVisible();

        // Tap play button on the sync card (the onRun action)
        await $(find.byIcon(AppIcons.play)).waitUntilVisible();
        await $(find.byIcon(AppIcons.play)).tap();
        await $.pumpAndSettle();

        if (backend.isFake) {
          final runCalls = backend.fake!.calls
              .where((c) => c.path == '/execute' && c.type == 'RunSync')
              .toList();
          expect(runCalls.length, 1);
        }
      } finally {
        await backend.stop();
      }
    },
    skip:
        config.skipReason(
          requiredResourceLabel: 'KOMODO_TEST_SYNC_NAME',
          requiredResourceValue: config.syncName,
        ) !=
        null,
  );
}

void main() => registerSyncsRunTests();
