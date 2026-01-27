import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/fake_komodo_backend.dart';
import '../support/patrol_test_config.dart';

void registerStackNotFoundTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'unhappy: stack detail not found shows message',
    ($) async {
      final backend = FakeKomodoBackend(
        expectedApiKey: 'test-key',
        expectedApiSecret: 'test-secret',
        port: 57868,
      );
      await backend.start();
      backend.queueError(
        path: '/read',
        type: 'GetStack',
        statusCode: 404,
        message: 'Stack not found',
      );

      try {
        await app.main();
        await $.pumpAndSettle();

        await loginWith(
          $,
          baseUrl: backend.baseUrl,
          apiKey: 'test-key',
          apiSecret: 'test-secret',
        );

        await $(find.byKey(const ValueKey('bottom_nav_resources')))
            .waitUntilVisible();
        await $(find.byKey(const ValueKey('bottom_nav_resources'))).tap();

        await $(find.byKey(const ValueKey('resources_stat_stacks')))
            .waitUntilVisible();
        await $(find.byKey(const ValueKey('resources_stat_stacks'))).tap();

        await $(find.text('Test Stack')).waitUntilVisible();
        await $(find.byKey(const ValueKey('stack_card_stack-1'))).tap();

        await $(find.textContaining('Stack not found')).waitUntilVisible();
      } finally {
        await backend.stop();
      }
    },
    skip: config.skipReason(requiresFake: true) != null,
  );
}

void main() => registerStackNotFoundTests();
