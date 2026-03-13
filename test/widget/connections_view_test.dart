import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/providers/connections_provider.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
import 'package:komodo_go/features/settings/presentation/views/connections_view.dart';

class _TestAuth extends Auth {
  _TestAuth(this._initialState);

  final AuthState _initialState;

  @override
  Future<AuthState> build() async => _initialState;
}

class _TestConnections extends Connections {
  _TestConnections(this._state);

  final ConnectionsState _state;

  @override
  Future<ConnectionsState> build() async => _state;
}

void main() {
  testWidgets(
    'Connections view shows saved connections without disconnect action',
    (
      tester,
    ) async {
      final connection = ConnectionProfile(
        id: 'conn-1',
        name: 'Production',
        baseUrl: 'https://komodo.example.com',
        createdAt: DateTime(2025),
        lastUsedAt: DateTime(2025),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => _TestAuth(const AuthState.unauthenticated()),
            ),
            connectionsProvider.overrideWith(
              () => _TestConnections(
                ConnectionsState(
                  connections: [connection],
                  activeConnectionId: connection.id,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: ConnectionsView()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Production'), findsOneWidget);
      expect(find.text('https://komodo.example.com'), findsOneWidget);
      expect(find.byTooltip('Disconnect'), findsNothing);
    },
  );
}
