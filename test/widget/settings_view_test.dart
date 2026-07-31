import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/settings/settings_view.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuth extends Auth {
  _TestAuth(this.initialState);

  final AuthState initialState;

  @override
  Future<AuthState> build() async => initialState;
}

class _TestActiveConnection extends ActiveConnection {
  _TestActiveConnection(this.initialConnection);

  final ActiveConnectionData initialConnection;

  @override
  ActiveConnectionData? build() => initialConnection;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Settings displays the Core version and 2.2 compatibility mode',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final profile = ConnectionProfile(
      id: 'connection-1',
      name: 'Production',
      baseUrl: 'https://komodo.example.com',
      createdAt: DateTime(2026),
      lastUsedAt: DateTime(2026),
    );
    const credentials = ApiCredentials(
      baseUrl: 'https://komodo.example.com',
      apiKey: 'key',
      apiSecret: 'secret',
    );
    final activeConnection = ActiveConnectionData(
      connectionId: profile.id,
      name: profile.name,
      credentials: credentials,
      coreVersion: KomodoCoreVersion.parse('2.2.0'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => _TestAuth(
              AuthState.authenticated(
                connection: profile,
                credentials: credentials,
              ),
            ),
          ),
          activeConnectionProvider.overrideWith(
            () => _TestActiveConnection(activeConnection),
          ),
        ],
        child: const MaterialApp(home: SettingsView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Komodo Core'), findsOneWidget);
    expect(find.text('v2.2.0'), findsOneWidget);
    expect(find.text('Komodo 2.2 compatibility mode'), findsOneWidget);
  });
}
