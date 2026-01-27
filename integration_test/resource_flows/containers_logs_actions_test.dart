import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerContainersLogsActionsTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'login → containers → restart/stop + log (fake backend)',
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

        await $(find.byKey(const ValueKey('bottom_nav_containers')))
            .waitUntilVisible();
        await $(find.byKey(const ValueKey('bottom_nav_containers'))).tap();

        final containerId = config.isFake ? 'container-1' : config.containerId;

        await $(find.byKey(ValueKey('container_card_menu_$containerId'))).tap();
        await $(find.byKey(ValueKey('container_card_restart_$containerId')))
            .tap();
        await $.pumpAndSettle();

        await $(find.byKey(ValueKey('container_card_menu_$containerId'))).tap();
        await $(find.byKey(ValueKey('container_card_stop_$containerId'))).tap();
        await $.pumpAndSettle();

        await $(find.byKey(ValueKey('container_card_$containerId'))).tap();
        await $(find.text('Log (tail)')).waitUntilVisible();

        if (backend.isFake) {
          final restartCalls = backend.fake!.calls
              .where((c) => c.path == '/execute' && c.type == 'RestartContainer')
              .toList();
          expect(restartCalls.length, 1);

          final stopCalls = backend.fake!.calls
              .where((c) => c.path == '/execute' && c.type == 'StopContainer')
              .toList();
          expect(stopCalls.length, 1);

          final logCalls = backend.fake!.calls
              .where((c) => c.path == '/read' && c.type == 'GetContainerLog')
              .toList();
          expect(logCalls, isNotEmpty);
        }
      } finally {
        await backend.stop();
      }
    },
    skip: config.skipReason(
      requiresDestructive: true,
      requiredResourceLabel: 'KOMODO_TEST_CONTAINER_ID',
      requiredResourceValue: config.containerId,
    ) != null,
  );
}

void main() => registerContainersLogsActionsTests();
