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
  });
}
