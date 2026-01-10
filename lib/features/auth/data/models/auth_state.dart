import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';

part 'auth_state.freezed.dart';

/// Represents the authentication state of the application.
@freezed
sealed class AuthState with _$AuthState {
  /// Initial state, checking for stored credentials.
  const factory AuthState.initial() = AuthStateInitial;

  /// Loading state during authentication operations.
  const factory AuthState.loading() = AuthStateLoading;

  /// Authenticated state with valid credentials.
  const factory AuthState.authenticated({
    required ConnectionProfile connection,
    required ApiCredentials credentials,
  }) = AuthStateAuthenticated;

  /// Unauthenticated state, user needs to log in.
  const factory AuthState.unauthenticated() = AuthStateUnauthenticated;

  /// Error state with failure information.
  const factory AuthState.error({required Failure failure}) = AuthStateError;
}

extension AuthStateX on AuthState {
  bool get isAuthenticated => this is AuthStateAuthenticated;
  bool get isLoading => this is AuthStateLoading;

  ApiCredentials? get credentials => switch (this) {
    AuthStateAuthenticated(:final credentials) => credentials,
    _ => null,
  };

  ConnectionProfile? get connection => switch (this) {
    AuthStateAuthenticated(:final connection) => connection,
    _ => null,
  };
}
