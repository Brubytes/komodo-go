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

/// Retry policy for the root `ProviderScope`.
///
/// A transient network failure is retried once after a short delay;
/// everything else surfaces immediately. Riverpod's retry callback does not
/// say whether the provider already holds a value (poll/refresh), so the
/// budget is kept at one: polling providers already retry on their next tick,
/// and repeated retries against an unreachable server multiply requests.
Duration? providerRetry(int retryCount, Object error) {
  if (retryCount >= maxProviderRetries) return null;
  if (error is FailureException && error.failure is NetworkFailure) {
    return const Duration(milliseconds: 400);
  }
  return null;
}

const maxProviderRetries = 1;
