import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/fake_komodo_backend.dart';

void registerTagsCrudTests() {
  patrolTest('settings → tags → create + delete tag (fake backend)', ($) async {
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

      await $(find.text('Resources')).waitUntilVisible();

      await $(find.text('Settings')).tap();
      await $(find.text('Tags')).scrollTo().tap();

      await $(find.text('Tags')).waitUntilVisible();

      // Create
      await $(find.byKey(const ValueKey('tags_add'))).tap();
      await $(find.byKey(const ValueKey('tag_editor_name'))).enterText(
        'Patrol Tag',
      );
      await $(find.byKey(const ValueKey('tag_editor_submit'))).tap();
      await $.pumpAndSettle();

      await $(find.text('Patrol Tag')).waitUntilVisible();

      final createCalls = backend.calls
          .where((c) => c.path == '/write' && c.type == 'CreateTag')
          .toList();
      expect(createCalls, isNotEmpty);

      // Delete
      await $(find.byKey(const ValueKey('tag_tile_menu_tag-2'))).tap();
      await $(find.byKey(const ValueKey('tag_tile_delete_tag-2'))).tap();

      await $(find.byKey(const ValueKey('tag_delete_confirm_tag-2'))).tap();
      await $.pumpAndSettle();

      expect(find.text('Patrol Tag'), findsNothing);

      final deleteCalls = backend.calls
          .where((c) => c.path == '/write' && c.type == 'DeleteTag')
          .toList();
      expect(deleteCalls.length, 1);
    } finally {
      await backend.stop();
    }
  });
}

void main() => registerTagsCrudTests();
