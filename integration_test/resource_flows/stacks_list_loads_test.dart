import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/fake_komodo_backend.dart';

void main() {
  patrolTest('stacks list loads via /read ListStacks (fake backend)', ($) async {
    final backend = FakeKomodoBackend(
      expectedApiKey: 'test-key',
      expectedApiSecret: 'test-secret',
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

      await $(find.text('Resources')).waitUntilVisible();

      // Isolate the list-loading call from login validation (GetVersion).
      backend.resetCalls();

      await $(find.text('Resources')).tap();
      await $(find.text('Stacks')).tap();

      await $(find.text('Test Stack')).waitUntilVisible();

      final listCalls = backend.calls
          .where((c) => c.path == '/read' && c.type == 'ListStacks')
          .toList();
      expect(listCalls, isNotEmpty);
    } finally {
      await backend.stop();
    }
  });
}
