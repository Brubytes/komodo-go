import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/stacks/presentation/views/stack_detail/stack_detail_sections.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/fake_komodo_backend.dart';

void registerStacksServicesLogsTests() {
  patrolTest('login → stacks → services + logs (fake backend)', ($) async {
    final backend = FakeKomodoBackend(
      expectedApiKey: 'test-key',
      expectedApiSecret: 'test-secret',
      port: 57868,
    );
    await backend.start();

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

      await $(find.byKey(const ValueKey('stack_tab_services'))).scrollTo();
      await $(find.byKey(const ValueKey('stack_tab_services'))).tap();
      await $.pumpAndSettle();

      final serviceCalls = backend.calls
          .where((c) => c.path == '/read' && c.type == 'ListStackServices')
          .toList();
      expect(serviceCalls, isNotEmpty);

      await $(find.byKey(const ValueKey('stack_tab_logs'))).scrollTo();
      await $(find.byKey(const ValueKey('stack_tab_logs'))).tap();

      final logCalls = backend.calls
          .where((c) => c.path == '/read' && c.type == 'GetStackLog')
          .toList();
      expect(logCalls, isNotEmpty);
    } finally {
      await backend.stop();
    }
  });
}

void main() => registerStacksServicesLogsTests();
