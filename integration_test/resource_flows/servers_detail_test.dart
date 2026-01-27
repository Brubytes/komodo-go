import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerServersDetailTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'login → servers → detail stats + system (fake backend)',
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

        await $(find.byKey(const ValueKey('resources_stat_servers')))
            .waitUntilVisible();
        await $(find.byKey(const ValueKey('resources_stat_servers'))).tap();

        final serverName = config.isFake ? 'Test Server' : config.serverName;
        await $(find.text(serverName)).waitUntilVisible();
        if (config.isFake) {
          await $(find.byKey(const ValueKey('server_card_server-1'))).tap();
        } else {
          await $(find.text(serverName)).tap();
        }

        await $(find.text('Stats')).tap();
        await $(find.text('Scale')).scrollTo();
        await $(find.text('Scale')).waitUntilVisible();

        await $(find.text('System')).tap();
        await $(find.text('Basics')).waitUntilVisible();

        if (backend.isFake) {
          final statsCalls = backend.fake!.calls
              .where((c) => c.path == '/read' && c.type == 'GetSystemStats')
              .toList();
          expect(statsCalls, isNotEmpty);

          final systemCalls = backend.fake!.calls
              .where((c) => c.path == '/read' && c.type == 'GetSystemInformation')
              .toList();
          expect(systemCalls, isNotEmpty);
        }
      } finally {
        await backend.stop();
      }
    },
    skip: config.skipReason(
      requiredResourceLabel: 'KOMODO_TEST_SERVER_NAME',
      requiredResourceValue: config.serverName,
    ) != null,
  );
}

void main() => registerServersDetailTests();
