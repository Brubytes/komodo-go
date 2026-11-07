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

  /// The server answered, but the response shape could not be decoded.
  /// [path] names the offending field, e.g. `StackConfig.additional_env_files`.
  const factory Failure.parse({String? path}) = ParseFailure;

  /// Unknown/unexpected error
  const factory Failure.unknown({String? message}) = UnknownFailure;
}

extension FailureX on Failure {
  String get displayMessage => switch (this) {
    NetworkFailure(:final message) => _networkMessage(message),
    ServerFailure(:final message) => message,
    AuthFailure(:final message) =>
      message ?? 'Authentication failed. Please log in again.',
    ParseFailure(:final path) => _parseMessage(path),
    UnknownFailure(:final message) =>
      message ?? 'An unexpected error occurred.',
  };

  String _parseMessage(String? path) {
    final where = path == null || path.isEmpty ? '' : ' ($path)';
    return "Komodo returned data this app version can't read$where. "
        'Please update the app or report this.';
  }

  String _networkMessage(String? message) {
    final normalized = message?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'Cannot reach the server. Check your connection and server address.';
    }
    if (normalized.toLowerCase() == 'could not connect to server') {
      return 'Cannot reach the server. Check your connection and server address.';
    }
    return normalized;
  }
}
