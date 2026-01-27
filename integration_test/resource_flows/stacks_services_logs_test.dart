import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerStacksServicesLogsTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'login → stacks → services + logs (fake backend)',
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

        await $(find.byKey(const ValueKey('resources_stat_stacks')))
            .waitUntilVisible();
        await $(find.byKey(const ValueKey('resources_stat_stacks'))).tap();

        final stackName = config.isFake ? 'Test Stack' : config.stackName;
        await $(find.text(stackName)).waitUntilVisible();
        if (config.isFake) {
          await $(find.byKey(const ValueKey('stack_card_stack-1'))).tap();
        } else {
          await $(find.text(stackName)).tap();
        }

        await $(find.byKey(const ValueKey('stack_tab_services'))).scrollTo();
        await $(find.byKey(const ValueKey('stack_tab_services'))).tap();
        await $.pumpAndSettle();

        if (backend.isFake) {
          final serviceCalls = backend.fake!.calls
              .where((c) => c.path == '/read' && c.type == 'ListStackServices')
              .toList();
          expect(serviceCalls, isNotEmpty);
        }

        await $(find.byKey(const ValueKey('stack_tab_logs'))).scrollTo();
        await $(find.byKey(const ValueKey('stack_tab_logs'))).tap();

        if (backend.isFake) {
          final logCalls = backend.fake!.calls
              .where((c) => c.path == '/read' && c.type == 'GetStackLog')
              .toList();
          expect(logCalls, isNotEmpty);
        }
      } finally {
        await backend.stop();
      }
    },
    skip: config.skipReason(
      requiredResourceLabel: 'KOMODO_TEST_STACK_NAME',
      requiredResourceValue: config.stackName,
    ) != null,
  );
}

void main() => registerStacksServicesLogsTests();
