import 'package:flutter/foundation.dart';
import 'package:komodo_go/core/api/custom_header.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/connections_provider.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
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
      if (connectionsState.activeConnectionId != null) {
        return const AuthState.error(
          failure: Failure.unknown(
            message:
                'The selected saved connection no longer exists. Choose another connection or add it again.',
          ),
        );
      }
      return const AuthState.unauthenticated();
    }

    final store = await ref.read(connectionsStoreProvider.future);
    final ApiCredentials? credentials;
    try {
      credentials = await store.getCredentials(activeProfile.id);
    } on Exception {
      ref.read(activeConnectionProvider.notifier).clear();
      return AuthState.error(
        failure: Failure.unknown(
          message:
              'Could not read the saved credentials for "${activeProfile.name}" from secure storage. '
              'Long-press the connection, choose Edit, and enter its API key and secret again.',
        ),
      );
    }
    if (credentials == null) {
      ref.read(activeConnectionProvider.notifier).clear();
      return AuthState.error(
        failure: Failure.auth(
          message:
              'The saved credentials for "${activeProfile.name}" are unavailable on this device. '
              'Long-press the connection, choose Edit, and enter its API key and secret again.',
        ),
      );
    }
    final resolvedCredentials = credentials;

    // Validate stored credentials for active connection
    final validationResult = await repository.validateCredentials(
      resolvedCredentials,
    );

    return await validationResult.fold(
      (failure) async {
        ref.read(activeConnectionProvider.notifier).clear();
        return AuthState.error(
          failure: _withConnectionContext(failure, activeProfile.name),
        );
      },
      (coreVersion) async {
        ref
            .read(activeConnectionProvider.notifier)
            .active = ActiveConnectionData(
          connectionId: activeProfile.id,
          name: activeProfile.name,
          credentials: resolvedCredentials,
          coreVersion: coreVersion,
        );
        await store.touchLastUsed(activeProfile.id);
        return AuthState.authenticated(
          connection: activeProfile,
          credentials: resolvedCredentials,
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
        try {
          await ref
              .read(connectionsProvider.notifier)
              .addConnection(name: displayName, credentials: credentials);
          await future;
        } on Exception {
          ref.read(activeConnectionProvider.notifier).clear();
          state = const AsyncValue.data(
            AuthState.error(
              failure: Failure.unknown(
                message:
                    'The server accepted the credentials, but they could not be saved securely on this device. '
                    'No connection was added. Retry, and restart the device if the problem continues.',
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> selectConnection(String connectionId) async {
    state = const AsyncValue.loading();
    final connections = ref.read(connectionsProvider).value?.connections;
    final connectionName = connections
        ?.where((connection) => connection.id == connectionId)
        .firstOrNull
        ?.name;

    try {
      // Changing the active connection rebuilds this provider (build() watches
      // connectionsProvider), which performs the single credential validation
      // and publishes the resulting auth state.
      await ref
          .read(connectionsProvider.notifier)
          .setActiveConnection(connectionId);
      await future;
    } on Exception {
      ref.read(activeConnectionProvider.notifier).clear();
      final connectionLabel = connectionName == null
          ? 'the saved connection'
          : '"$connectionName"';
      state = AsyncValue.data(
        AuthState.error(
          failure: Failure.unknown(
            message:
                'Could not select $connectionLabel. Secure storage or local connection data could not be read. '
                'Try editing the connection and saving its credentials again.',
          ),
        ),
      );
    }
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

  Failure _withConnectionContext(Failure failure, String connectionName) {
    final message =
        'Could not connect to "$connectionName". '
        '${failure.displayMessage}';
    return switch (failure) {
      NetworkFailure() => Failure.network(message: message),
      ServerFailure(:final trace, :final statusCode) => Failure.server(
        message: message,
        trace: trace,
        statusCode: statusCode,
      ),
      AuthFailure() => Failure.auth(message: message),
      UnknownFailure() => Failure.unknown(message: message),
    };
  }
}
