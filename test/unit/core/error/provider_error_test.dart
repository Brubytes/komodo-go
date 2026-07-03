import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/error/provider_error.dart';

void main() {
  group('unwrapOrThrow', () {
    test('returns the value for Right', () {
      final result = unwrapOrThrow(const Right<Failure, int>(42));

      expect(result, 42);
    });

    test('throws an exception for Left', () {
      const result = Left<Failure, int>(Failure.server(message: 'Boom'));

      expect(
        () => unwrapOrThrow(result),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Boom'),
          ),
        ),
      );
    });

    test('throws FailureException carrying the original failure', () {
      const failure = Failure.network(message: 'offline');
      const result = Left<Failure, int>(failure);

      expect(
        () => unwrapOrThrow(result),
        throwsA(
          isA<FailureException>().having((e) => e.failure, 'failure', failure),
        ),
      );
    });

    test('FailureException.toString is the user-facing display message', () {
      const failure = Failure.server(message: 'Boom');

      expect(const FailureException(failure).toString(), 'Boom');
    });
  });

  group('providerRetry', () {
    test('retries network failures with exponential backoff', () {
      const error = FailureException(Failure.network());

      expect(providerRetry(0, error), const Duration(milliseconds: 200));
      expect(providerRetry(1, error), const Duration(milliseconds: 400));
      expect(providerRetry(2, error), const Duration(milliseconds: 800));
    });

    test('stops after 3 retries', () {
      const error = FailureException(Failure.network());

      expect(providerRetry(3, error), isNull);
    });

    test('does not retry non-network failures', () {
      expect(
        providerRetry(0, const FailureException(Failure.server(message: 'x'))),
        isNull,
      );
      expect(
        providerRetry(0, const FailureException(Failure.auth())),
        isNull,
      );
      expect(providerRetry(0, Exception('plain')), isNull);
    });
  });
}
