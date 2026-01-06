import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../data/models/auth_state.dart';
import '../../data/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

/// Manages authentication state for the application.
@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  @override
  Future<AuthState> build() async {
    final repository = ref.read(authRepositoryProvider);

    // Check for stored credentials
    final credentials = await repository.getStoredCredentials();

    if (credentials == null) {
      return const AuthState.unauthenticated();
    }

    // Validate stored credentials
    final validationResult = await repository.validateCredentials(credentials);

    return validationResult.fold(
      (failure) => const AuthState.unauthenticated(),
      (_) {
        // Set the base URL for the API client
        ref.read(baseUrlProvider.notifier).setBaseUrl(credentials.baseUrl);
        return AuthState.authenticated(credentials: credentials);
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

    state = AsyncValue.data(
      result.fold(
        (failure) => AuthState.error(failure: failure),
        (credentials) {
          // Set the base URL for the API client
          ref.read(baseUrlProvider.notifier).setBaseUrl(credentials.baseUrl);
          return AuthState.authenticated(credentials: credentials);
        },
      ),
    );
  }

  /// Logs out the current user.
  Future<void> logout() async {
    state = const AsyncValue.loading();

    final repository = ref.read(authRepositoryProvider);
    await repository.logout();

    // Clear the base URL
    ref.read(baseUrlProvider.notifier).clear();

    state = const AsyncValue.data(AuthState.unauthenticated());
  }
}
