import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerStacksDestroyTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'login → stacks → destroy stack (fake backend)',
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
          // Open overflow menu for the first stack card.
          await $(find.byKey(const ValueKey('stack_card_menu_stack-1'))).tap();
          await $(find.byKey(const ValueKey('stack_card_destroy_stack-1'))).tap();
        } else {
          await $(find.text(stackName)).tap();
          await $(find.byIcon(AppIcons.moreVertical)).tap();
          await $(find.text('Destroy')).tap();
        }
        await $(find.text('Destroy')).tap(); // confirm dialog

        await $.pumpAndSettle();

        if (backend.isFake) {
          // Stack should be gone after refresh.
          expect(find.text('Test Stack'), findsNothing);

          final destroyCalls = backend.fake!.calls
              .where((c) => c.path == '/execute' && c.type == 'DestroyStack')
              .toList();
          expect(destroyCalls.length, 1);
        }
      } finally {
        await backend.stop();
      }
    },
    skip: config.skipReason(
      requiresDestructive: true,
      requiredResourceLabel: 'KOMODO_TEST_STACK_NAME',
      requiredResourceValue: config.stackName,
    ) != null,
  );
}

void main() => registerStacksDestroyTests();
