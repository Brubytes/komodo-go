import 'package:fpdart/fpdart.dart';

import 'package:komodo_go/core/error/failures.dart';

/// Thrown when a provider unwraps a [Failure] from a repository result.
///
/// Carries the original [Failure] so the root `ProviderScope` retry policy
/// can distinguish transient network failures from permanent ones.
class FailureException implements Exception {
  const FailureException(this.failure);

  final Failure failure;

  @override
  String toString() => failure.displayMessage;
}

T unwrapOrThrow<T>(Either<Failure, T> result) {
  return result.fold(
    (failure) => throw FailureException(failure),
    (value) => value,
  );
}

/// Retry policy for the root `ProviderScope`: transient network failures are
/// retried up to 3 times with exponential backoff; everything else surfaces
/// immediately.
Duration? providerRetry(int retryCount, Object error) {
  if (retryCount >= 3) return null;
  if (error is FailureException && error.failure is NetworkFailure) {
    return Duration(milliseconds: 200 * (1 << retryCount));
  }
  return null;
}
