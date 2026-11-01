import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resources_view.dart';
import 'package:komodo_go/core/theme/app_theme.dart';
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
import 'package:komodo_go/features/procedures/data/repositories/procedure_repository.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/features/syncs/data/repositories/sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final scale in [1.0, 1.3]) {
    for (final width in [360.0, 466, 589, 660, 720, 790, 1100, 1300]) {
      testWidgets('lays out at local width $width, text scale $scale', (
        tester,
      ) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = Size(width + 80, 900);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              serverRepositoryProvider.overrideWithValue(null),
              deploymentRepositoryProvider.overrideWithValue(null),
              stackRepositoryProvider.overrideWithValue(null),
              repoRepositoryProvider.overrideWithValue(null),
              syncRepositoryProvider.overrideWithValue(null),
              buildRepositoryProvider.overrideWithValue(null),
              procedureRepositoryProvider.overrideWithValue(null),
              actionRepositoryProvider.overrideWithValue(null),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              // A 80pt "rail" beside the content, like the tablet shell.
              home: const Row(
                children: [
                  SizedBox(width: 80),
                  Expanded(child: ResourcesView()),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
      });
    }
  }
}
