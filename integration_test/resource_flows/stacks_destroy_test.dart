import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/fake_komodo_backend.dart';

void main() {
  patrolTest('login → stacks → destroy stack (fake backend)', ($) async {
    final backend = FakeKomodoBackend(
      expectedApiKey: 'test-key',
      expectedApiSecret: 'test-secret',
    );
    await backend.start();

    try {
      await app.main();
      await $.pumpAndSettle();

      // If we're already logged in (local dev), log out first.
      if ($(find.text('Resources')).exists &&
          !$(find.text('Server URL')).exists) {
        await $(find.text('Settings')).tap();
        await $(find.text('Logout')).tap();
        await $(find.text('Logout')).tap(); // confirm dialog
        await $.pumpAndSettle();
      }

      await $(find.byKey(const Key('login_serverUrl')))
          .enterText(backend.baseUrl);
      await $(find.byKey(const Key('login_apiKey'))).enterText('test-key');
      await $(find.byKey(const Key('login_apiSecret')))
          .enterText('test-secret');
      await $(find.byKey(const Key('login_saveConnection'))).tap();

      await $(find.text('Resources')).waitUntilVisible();
      await $(find.text('Stacks')).tap();

      await $(find.text('Test Stack')).waitUntilVisible();

      // Open overflow menu for the first stack card.
      await $(find.byKey(const ValueKey('stack_card_menu'))).first.tap();
      await $(find.text('Destroy')).tap();
      await $(find.text('Destroy')).tap(); // confirm dialog

      await $.pumpAndSettle();

      // Stack should be gone after refresh.
      expect(find.text('Test Stack'), findsNothing);

      final destroyCalls = backend.calls
          .where((c) => c.path == '/execute' && c.type == 'DestroyStack')
          .toList();
      expect(destroyCalls.length, 1);
    } finally {
      await backend.stop();
    }
  });
}
