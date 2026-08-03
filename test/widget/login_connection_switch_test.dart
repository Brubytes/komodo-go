import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/connections_provider.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
import 'package:komodo_go/features/auth/presentation/views/login_view.dart';

class _TestAuth extends Auth {
  _TestAuth(this._initialState, {this.failureOnSelect});

  final AuthState _initialState;
  final Failure? failureOnSelect;
  String? selectedConnectionId;

  @override
  Future<AuthState> build() async => _initialState;

  @override
  Future<void> selectConnection(String connectionId) async {
    selectedConnectionId = connectionId;
    if (failureOnSelect case final failure?) {
      state = AsyncValue.data(AuthState.error(failure: failure));
    }
  }
}

class _TestConnections extends Connections {
  _TestConnections(this._state);

  final ConnectionsState _state;

  @override
  Future<ConnectionsState> build() async => _state;
}

void main() {
  testWidgets('Selects a saved connection from login view', (tester) async {
    final connection = ConnectionProfile(
      id: 'conn-1',
      name: 'Production',
      baseUrl: 'https://komodo.example.com',
      createdAt: DateTime(2025),
      lastUsedAt: DateTime(2025),
    );
    final testAuth = _TestAuth(const AuthState.unauthenticated());
    final testConnections = _TestConnections(
      ConnectionsState(connections: [connection], activeConnectionId: null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => testAuth),
          connectionsProvider.overrideWith(() => testConnections),
        ],
        child: const MaterialApp(home: LoginView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Saved connections'), findsOneWidget);

    await tester.tap(find.text('Production'));
    await tester.pump();

    expect(testAuth.selectedConnectionId, 'conn-1');
  });

  testWidgets('Shows detailed feedback when a saved connection fails', (
    tester,
  ) async {
    final connection = ConnectionProfile(
      id: 'conn-1',
      name: 'Production VPS',
      baseUrl: 'https://komodo.example.com',
      createdAt: DateTime(2025),
      lastUsedAt: DateTime(2025),
    );
    final testAuth = _TestAuth(
      const AuthState.unauthenticated(),
      failureOnSelect: const Failure.auth(
        message:
            'The saved credentials are unavailable. Enter the API key and secret again.',
      ),
    );
    final testConnections = _TestConnections(
      ConnectionsState(connections: [connection], activeConnectionId: null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => testAuth),
          connectionsProvider.overrideWith(() => testConnections),
        ],
        child: const MaterialApp(home: LoginView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Production VPS'));
    await tester.pump();

    expect(find.text('Could not connect to Production VPS'), findsOneWidget);
    expect(
      find.text(
        'The saved credentials are unavailable. Enter the API key and secret again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Edit credentials'), findsOneWidget);
  });
}
