import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../../../core/providers/connections_provider.dart';
import '../../data/models/auth_state.dart';
import '../../data/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

/// Manages authentication state for the application.
@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  @override
  Future<AuthState> build() async {
    final repository = ref.read(authRepositoryProvider);
    final connectionsState = await ref.watch(connectionsProvider.future);
    final activeProfile = connectionsState.activeConnection;

    if (activeProfile == null) {
      ref.read(activeConnectionProvider.notifier).clear();
      return const AuthState.unauthenticated();
    }

    final store = await ref.read(connectionsStoreProvider.future);
    final credentials = await store.getCredentials(activeProfile.id);
    if (credentials == null) {
      ref.read(activeConnectionProvider.notifier).clear();
      return const AuthState.unauthenticated();
    }

    // Validate stored credentials for active connection
    final validationResult = await repository.validateCredentials(credentials);

    return await validationResult.fold(
      (failure) async {
        ref.read(activeConnectionProvider.notifier).clear();
        return AuthState.error(failure: failure);
      },
      (_) async {
        ref
            .read(activeConnectionProvider.notifier)
            .setActive(
              ActiveConnectionData(
                connectionId: activeProfile.id,
                name: activeProfile.name,
                credentials: credentials,
              ),
            );
        await store.touchLastUsed(activeProfile.id);
        return AuthState.authenticated(
          connection: activeProfile,
          credentials: credentials,
        );
      },
    );
  }

  /// Attempts to log in with the provided credentials.
  Future<void> login({
    required String baseUrl,
    required String apiKey,
    required String apiSecret,
  }) async {
    state = const AsyncValue.loading();

    final repository = ref.read(authRepositoryProvider);

    final result = await repository.authenticate(
      baseUrl: baseUrl,
      apiKey: apiKey,
      apiSecret: apiSecret,
    );

    state = await result.fold(
      (failure) async => AsyncValue.data(AuthState.error(failure: failure)),
      (credentials) async {
        final name = _deriveNameFromBaseUrl(credentials.baseUrl);
        final profile = await ref
            .read(connectionsProvider.notifier)
            .addConnection(name: name, credentials: credentials);

        ref
            .read(activeConnectionProvider.notifier)
            .setActive(
              ActiveConnectionData(
                connectionId: profile.id,
                name: profile.name,
                credentials: credentials,
              ),
            );
        final store = await ref.read(connectionsStoreProvider.future);
        await store.touchLastUsed(profile.id);

        return AsyncValue.data(
          AuthState.authenticated(
            connection: profile,
            credentials: credentials,
          ),
        );
      },
    );
  }

  Future<void> selectConnection(String connectionId) async {
    state = const AsyncValue.loading();
    await ref
        .read(connectionsProvider.notifier)
        .setActiveConnection(connectionId);

    final store = await ref.read(connectionsStoreProvider.future);
    final credentials = await store.getCredentials(connectionId);
    if (credentials == null) {
      await ref.read(connectionsProvider.notifier).setActiveConnection(null);
      ref.read(activeConnectionProvider.notifier).clear();
      state = const AsyncValue.data(AuthState.unauthenticated());
      return;
    }

    final repository = ref.read(authRepositoryProvider);
    final validation = await repository.validateCredentials(credentials);

    state = await validation.fold(
      (failure) async {
        ref.read(activeConnectionProvider.notifier).clear();
        return AsyncValue.data(AuthState.error(failure: failure));
      },
      (_) async {
        final connectionsState = ref.read(connectionsProvider).asData?.value;
        final profile = connectionsState?.activeConnection;
        if (profile != null) {
          ref
              .read(activeConnectionProvider.notifier)
              .setActive(
                ActiveConnectionData(
                  connectionId: profile.id,
                  name: profile.name,
                  credentials: credentials,
                ),
              );
          await store.touchLastUsed(profile.id);
          return AsyncValue.data(
            AuthState.authenticated(
              connection: profile,
              credentials: credentials,
            ),
          );
        }

        ref.read(activeConnectionProvider.notifier).clear();
        return const AsyncValue.data(AuthState.unauthenticated());
      },
    );
  }

  /// Logs out the current user.
  Future<void> logout() async {
    state = const AsyncValue.loading();

    await ref.read(connectionsProvider.notifier).setActiveConnection(null);
    ref.read(activeConnectionProvider.notifier).clear();

    state = const AsyncValue.data(AuthState.unauthenticated());
  }

  String _deriveNameFromBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    final host = uri?.host;
    if (host != null && host.isNotEmpty) {
      return host;
    }
    return baseUrl;
  }
}
