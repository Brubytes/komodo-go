import 'package:fpdart/fpdart.dart';

import 'failures.dart';

T unwrapOrThrow<T>(Either<Failure, T> result) {
  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (value) => value,
  );
}
