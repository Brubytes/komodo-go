import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';

void registerLoginUnreachableServerTests() {
  patrolTest('unhappy: unreachable server shows login error', ($) async {
    await app.main();
    await $.pumpAndSettle();

    await loginWith(
      $,
      // Closed port on localhost should fail fast with connection refused.
      baseUrl: 'http://127.0.0.1:1',
      apiKey: 'test-key',
      apiSecret: 'test-secret',
    );

    await $(
      find.text(
        'Cannot reach the server. Check your connection and server address.',
      ),
    ).waitUntilVisible();
  });
}

void main() => registerLoginUnreachableServerTests();
