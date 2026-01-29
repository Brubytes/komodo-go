import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../support/app_steps.dart';
import '../support/patrol_test_config.dart';

void registerReposPullTests() {
  final config = PatrolTestConfig.fromEnvironment();
  patrolTest(
    'login → repos → detail → pull (fake backend)',
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

        // Navigate to Resources
        await $(
          find.byKey(const ValueKey('bottom_nav_resources')),
        ).waitUntilVisible();
        await $(find.byKey(const ValueKey('bottom_nav_resources'))).tap();

        // Open Repos list
        await $(
          find.byKey(const ValueKey('resources_stat_repos')),
        ).waitUntilVisible();
        await $(find.byKey(const ValueKey('resources_stat_repos'))).tap();

        // Wait for repo card and tap Pull action directly from card menu
        final repoName = config.isFake ? 'Test Repo' : config.repoName;
        await $(find.text(repoName)).waitUntilVisible();

        // Open card menu and tap Pull
        await $(
          find.byKey(const ValueKey('repo_card_menu_repo-1')),
        ).waitUntilVisible();
        await $(find.byKey(const ValueKey('repo_card_menu_repo-1'))).tap();
        await $(find.byKey(const ValueKey('repo_card_pull_repo-1'))).tap();
        await $.pumpAndSettle();

        if (backend.isFake) {
          final pullCalls = backend.fake!.calls
              .where((c) => c.path == '/execute' && c.type == 'PullRepo')
              .toList();
          expect(pullCalls.length, 1);
        }
      } finally {
        await backend.stop();
      }
    },
    skip:
        config.skipReason(
          requiredResourceLabel: 'KOMODO_TEST_REPO_NAME',
          requiredResourceValue: config.repoName,
        ) !=
        null,
  );
}

void main() => registerReposPullTests();
