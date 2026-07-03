import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';

final _profile = ConnectionProfile(
  id: 'c1',
  name: 'Test',
  baseUrl: 'https://komodo.example',
  createdAt: DateTime.utc(2026),
  lastUsedAt: DateTime.utc(2026),
);

const _credentials = ApiCredentials(
  baseUrl: 'https://komodo.example',
  apiKey: 'key',
  apiSecret: 'secret',
);

final _authenticated = AuthState.authenticated(
  connection: _profile,
  credentials: _credentials,
);

class _TestAuth extends Auth {
  _TestAuth(this._initial);

  final AuthState _initial;

  @override
  Future<AuthState> build() async => _initial;

  AsyncValue<AuthState> get authValue => state;
  set authValue(AsyncValue<AuthState> value) => state = value;
}

/// Builds the AsyncValue an auth refresh produces (loading with the previous
/// value retained) using a real container, since `copyWithPrevious` is
/// internal to Riverpod.
Future<AsyncValue<AuthState>> _refreshingAuthValue() async {
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(() => _TestAuth(_authenticated)),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(authProvider, (_, _) {});
  await container.read(authProvider.future);
  container.invalidate(authProvider);
  return sub.read();
}

void main() {
  group('authRedirect', () {
    test('gates on splash during initial restore', () {
      const loading = AsyncValue<AuthState>.loading();

      expect(
        authRedirect(authState: loading, matchedLocation: AppRoutes.home),
        AppRoutes.splash,
      );
      expect(
        authRedirect(authState: loading, matchedLocation: AppRoutes.splash),
        isNull,
      );
    });

    test(
      'does not disturb navigation during a refresh with previous value',
      () async {
        final refreshing = await _refreshingAuthValue();
        expect(refreshing.isLoading, isTrue);
        expect(refreshing.hasValue, isTrue);

        expect(
          authRedirect(
            authState: refreshing,
            matchedLocation: AppRoutes.connections,
          ),
          isNull,
        );
      },
    );

    test('redirects unauthenticated users to login', () {
      const unauthenticated = AsyncValue.data(AuthState.unauthenticated());

      expect(
        authRedirect(
          authState: unauthenticated,
          matchedLocation: AppRoutes.home,
        ),
        AppRoutes.login,
      );
      expect(
        authRedirect(
          authState: unauthenticated,
          matchedLocation: AppRoutes.login,
        ),
        isNull,
      );
    });

    test('treats auth errors as unauthenticated', () {
      const error = AsyncValue.data(
        AuthState.error(failure: Failure.auth()),
      );

      expect(
        authRedirect(authState: error, matchedLocation: AppRoutes.home),
        AppRoutes.login,
      );
    });

    test('sends authenticated users away from splash and login', () {
      final authenticated = AsyncValue.data(_authenticated);

      expect(
        authRedirect(
          authState: authenticated,
          matchedLocation: AppRoutes.login,
        ),
        AppRoutes.home,
      );
      expect(
        authRedirect(
          authState: authenticated,
          matchedLocation: AppRoutes.splash,
        ),
        AppRoutes.home,
      );
      expect(
        authRedirect(
          authState: authenticated,
          matchedLocation: AppRoutes.stacks,
        ),
        isNull,
      );
    });
  });

  group('appRouter', () {
    test('keeps the same router instance across auth emissions', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _TestAuth(_authenticated)),
        ],
      );
      addTearDown(container.dispose);

      final routerSub = container.listen(appRouterProvider, (_, _) {});
      final router1 = routerSub.read();
      await container.read(authProvider.future);

      _TestAuth auth() => container.read(authProvider.notifier) as _TestAuth;
      auth().authValue = const AsyncValue.loading();
      await container.pump();
      auth().authValue = AsyncValue.data(_authenticated);
      await container.pump();

      expect(identical(router1, routerSub.read()), isTrue);
    });
  });
}
