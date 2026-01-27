import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerStacksListLoadsTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'stacks list loads via /read ListStacks (fake backend)',
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

        await $(find.text('Resources')).waitUntilVisible();

        await $(find.text('Resources')).tap();
        await $(find.text('Stacks')).tap();

        await $(find.text('Test Stack')).waitUntilVisible();

        // Isolate the list-loading call from login validation (GetVersion) and
        // any cached state from previous test cases.
        backend.fake!.resetCalls();
        await pullToRefresh($);
        await $(find.text('Test Stack')).waitUntilVisible();

        final listCalls = backend.fake!.calls
            .where((c) => c.path == '/read' && c.type == 'ListStacks')
            .toList();
        expect(listCalls, isNotEmpty);
      } finally {
        await backend.stop();
      }
    },
    skip: config.skipReason(requiresFake: true) != null,
  );
}

void main() => registerStacksListLoadsTests();
