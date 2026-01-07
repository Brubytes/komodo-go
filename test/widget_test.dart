import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/app.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
import 'package:komodo_go/features/auth/presentation/views/auth_loading_view.dart';
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

  testWidgets('Shows loading screen while restoring auth', (
    WidgetTester tester,
  ) async {
    final never = Completer<AuthState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _TestAuth(never.future)),
        ],
        child: const KomodoApp(),
      ),
    );

    await tester.pump();

    expect(find.byKey(AuthLoadingView.loadingKey), findsOneWidget);
  });
}
