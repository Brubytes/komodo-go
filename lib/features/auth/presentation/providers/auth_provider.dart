import 'package:flutter/foundation.dart';
import 'package:komodo_go/core/api/custom_header.dart';
import 'package:komodo_go/core/providers/connections_provider.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/data/repositories/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_provider.g.dart';

/// Manages authentication state for the application.
@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  @override
  Future<AuthState> build() async {
    if (kDebugMode) {
      const delayMs = int.fromEnvironment('AUTH_BOOT_DELAY_MS');
      if (delayMs > 0) {
        // The analyzer const-folds delayMs to 0 without --dart-define.
        // ignore: avoid_redundant_argument_values, use_named_constants
        await Future<void>.delayed(const Duration(milliseconds: delayMs));
      }
    }

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
      (coreVersion) async {
        ref
            .read(activeConnectionProvider.notifier)
            .active = ActiveConnectionData(
          connectionId: activeProfile.id,
          name: activeProfile.name,
          credentials: credentials,
          coreVersion: coreVersion,
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
    String? name,
    bool proxyAuthEnabled = false,
    String? proxyAuthUsername,
    String? proxyAuthPassword,
    List<CustomHeader> customHeaders = const <CustomHeader>[],
  }) async {
    state = const AsyncValue.loading();

    final repository = ref.read(authRepositoryProvider);

    final result = await repository.authenticate(
      baseUrl: baseUrl,
      apiKey: apiKey,
      apiSecret: apiSecret,
      proxyAuthEnabled: proxyAuthEnabled,
      proxyAuthUsername: proxyAuthUsername,
      proxyAuthPassword: proxyAuthPassword,
      customHeaders: customHeaders,
    );

    await result.fold(
      (failure) async {
        state = AsyncValue.data(AuthState.error(failure: failure));
      },
      (credentials) async {
        final displayName = (name == null || name.trim().isEmpty)
            ? _deriveNameFromBaseUrl(credentials.baseUrl)
            : name.trim();
        // Adding the connection (and making it active) rebuilds this
        // provider, which validates the stored credentials and publishes the
        // resulting auth state — build() is the single writer, so no second
        // validation can race with a manual state assignment here.
        await ref
            .read(connectionsProvider.notifier)
            .addConnection(name: displayName, credentials: credentials);
        await future;
      },
    );
  }

  Future<void> selectConnection(String connectionId) async {
    state = const AsyncValue.loading();
    // Changing the active connection rebuilds this provider (build() watches
    // connectionsProvider), which performs the single credential validation
    // and publishes the resulting auth state.
    await ref
        .read(connectionsProvider.notifier)
        .setActiveConnection(connectionId);
    await future;
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
