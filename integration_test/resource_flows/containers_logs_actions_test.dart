import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/fake_komodo_backend.dart';

void registerContainersLogsActionsTests() {
  patrolTest('login → containers → restart/stop + log (fake backend)', (
    $,
  ) async {
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

      await $(find.byKey(const ValueKey('bottom_nav_containers')))
          .waitUntilVisible();
      await $(find.byKey(const ValueKey('bottom_nav_containers'))).tap();

      await $(find.text('nginx')).waitUntilVisible();

      await $(find.byKey(const ValueKey('container_card_menu_container-1')))
          .tap();
      await $(find.byKey(const ValueKey('container_card_restart_container-1')))
          .tap();
      await $(find.text('Action completed successfully')).waitUntilVisible();

      await $(find.byKey(const ValueKey('container_card_menu_container-1')))
          .tap();
      await $(find.byKey(const ValueKey('container_card_stop_container-1')))
          .tap();
      await $(find.text('Action completed successfully')).waitUntilVisible();

      await $(find.byKey(const ValueKey('container_card_container-1'))).tap();
      await $(find.text('Log (tail)')).waitUntilVisible();
      await $(find.text('Container log: hello world')).waitUntilVisible();

      final restartCalls = backend.calls
          .where((c) => c.path == '/execute' && c.type == 'RestartContainer')
          .toList();
      expect(restartCalls.length, 1);

      final stopCalls = backend.calls
          .where((c) => c.path == '/execute' && c.type == 'StopContainer')
          .toList();
      expect(stopCalls.length, 1);

      final logCalls = backend.calls
          .where((c) => c.path == '/read' && c.type == 'GetContainerLog')
          .toList();
      expect(logCalls, isNotEmpty);
    } finally {
      await backend.stop();
    }
  });
}

void main() => registerContainersLogsActionsTests();
