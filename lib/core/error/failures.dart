import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

/// Represents different types of failures that can occur in the application.
@freezed
sealed class Failure with _$Failure {
  /// Network-related failure (no internet, timeout, etc.)
  const factory Failure.network({String? message}) = NetworkFailure;

  /// Server-side error with message and optional trace
  const factory Failure.server({
    required String message,
    String? trace,
    int? statusCode,
  }) = ServerFailure;

  /// Authentication failure (invalid credentials, expired token, etc.)
  const factory Failure.auth({String? message}) = AuthFailure;

  /// Unknown/unexpected error
  const factory Failure.unknown({String? message}) = UnknownFailure;
}

extension FailureX on Failure {
  String get displayMessage => switch (this) {
    NetworkFailure(:final message) =>
      message ?? 'Network error. Please check your connection.',
    ServerFailure(:final message) => message,
    AuthFailure(:final message) =>
      message ?? 'Authentication failed. Please log in again.',
    UnknownFailure(:final message) =>
      message ?? 'An unexpected error occurred.',
  };
}
