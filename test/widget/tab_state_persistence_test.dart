import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/app.dart';
import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
import 'package:komodo_go/features/procedures/data/repositories/procedure_repository.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/features/syncs/data/repositories/sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuth extends Auth {
  _TestAuth(this._buildFuture);

  final Future<AuthState> _buildFuture;

  @override
  Future<AuthState> build() => _buildFuture;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'Keeps tab navigation stacks while switching tabs',
    (tester) async {
      final authenticated = AuthState.authenticated(
        connection: ConnectionProfile(
          id: 'test',
          name: 'Test',
          baseUrl: 'http://localhost',
          createdAt: DateTime(2025),
          lastUsedAt: DateTime(2025),
        ),
        credentials: const ApiCredentials(
          baseUrl: 'http://localhost',
          apiKey: 'test',
          apiSecret: 'test',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => _TestAuth(Future.value(authenticated)),
            ),
            serverRepositoryProvider.overrideWithValue(null),
            deploymentRepositoryProvider.overrideWithValue(null),
            stackRepositoryProvider.overrideWithValue(null),
            repoRepositoryProvider.overrideWithValue(null),
            syncRepositoryProvider.overrideWithValue(null),
            buildRepositoryProvider.overrideWithValue(null),
            procedureRepositoryProvider.overrideWithValue(null),
            actionRepositoryProvider.overrideWithValue(null),
          ],
          child: const KomodoApp(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Resources'), findsOneWidget);

      await tester.tap(find.text('Stacks'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Stacks'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);

      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Stacks'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Resources'), findsNothing);

      // Re-tapping the active tab should pop its stack back to the branch root.
      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Resources'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Stacks'), findsNothing);
    },
  );
}
