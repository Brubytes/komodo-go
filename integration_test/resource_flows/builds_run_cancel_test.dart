import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerBuildsRunCancelTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'login → builds → run + cancel build (fake backend)',
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

        await $(find.byKey(const ValueKey('resources_stat_builds')))
            .waitUntilVisible();
        await $(find.byKey(const ValueKey('resources_stat_builds'))).tap();

        final buildName = config.isFake ? 'Test Build' : config.buildName;
        await $(find.text(buildName)).waitUntilVisible();
        await $(find.text(buildName)).tap();

        await $(find.byIcon(AppIcons.moreVertical)).tap();
        await $(find.text('Run build')).tap();
        await $.pumpAndSettle();

        await $(find.byIcon(AppIcons.moreVertical)).tap();
        await $(find.text('Cancel')).tap();
        await $.pumpAndSettle();

        if (backend.isFake) {
          final runCalls = backend.fake!.calls
              .where((c) => c.path == '/execute' && c.type == 'RunBuild')
              .toList();
          expect(runCalls.length, 1);

          final cancelCalls = backend.fake!.calls
              .where((c) => c.path == '/execute' && c.type == 'CancelBuild')
              .toList();
          expect(cancelCalls.length, 1);
        }
      } finally {
        await backend.stop();
      }
    },
    skip: config.skipReason(
      requiredResourceLabel: 'KOMODO_TEST_BUILD_NAME',
      requiredResourceValue: config.buildName,
    ) != null,
  );
}

void main() => registerBuildsRunCancelTests();
