import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';

void main() {
  group('apiCall parse failure mapping', () {
    test('top-level CheckedFromJsonException names class and key', () async {
      final result = await apiCall<void>(
        () async =>
            KomodoStack.fromJson(<String, dynamic>{'id': 'a', 'name': 5}),
      );
      final failure = result.fold((f) => f, (_) => fail('expected Left'));
      expect(failure, isA<ParseFailure>());
      expect(
        (failure as ParseFailure).path,
        'KomodoStack.name',
      );
      expect(
        failure.displayMessage,
        "Komodo returned data this app version can't read "
        '(KomodoStack.name). Please update the app or report this.',
      );
    });

    test('nested failure names the innermost class and key', () async {
      final result = await apiCall<void>(
        () async => KomodoStack.fromJson(<String, dynamic>{
          'id': 'a',
          'name': 'n',
          'config': <String, dynamic>{
            'server_id': <String, dynamic>{'x': 1},
          },
        }),
      );
      final failure = result.fold((f) => f, (_) => fail('expected Left'));
      expect(failure, isA<ParseFailure>());
      expect(failure.displayMessage, contains('StackConfig.server_id'));
      expect(failure.displayMessage, isNot(contains('_StackConfig')));
    });

    test('plain TypeError becomes a readable parse failure', () async {
      final result = await apiCall<int>(() async {
        final Object response = <String, dynamic>{};
        return (response as List<dynamic>).length;
      });
      final failure = result.fold((f) => f, (_) => fail('expected Left'));
      expect(failure, isA<ParseFailure>());
      expect((failure as ParseFailure).path, isNull);
      expect(failure.displayMessage, isNot(contains('subtype')));
      expect(failure.displayMessage, contains("can't read"));
    });

    test('parse failure wins over a repository onUnknown', () async {
      final result = await apiCall<void>(
        () async =>
            KomodoStack.fromJson(<String, dynamic>{'id': 'a', 'name': 5}),
        onUnknown: (e) => Failure.unknown(message: e.toString()),
      );
      expect(result.fold((f) => f, (_) => null), isA<ParseFailure>());
    });

    test('non-parse errors still use onUnknown / unknown', () async {
      final custom = await apiCall<void>(
        () async => throw StateError('x'),
        onUnknown: (e) => const Failure.unknown(message: 'custom'),
      );
      expect(custom.fold((f) => f.displayMessage, (_) => ''), 'custom');
      final plain = await apiCall<void>(() async => throw StateError('x'));
      expect(
        plain.fold((f) => f, (_) => null),
        isA<UnknownFailure>(),
      );
    });

    test('ApiException mapping is unchanged', () async {
      final unauthorized = await apiCall<void>(
        () async => throw const ApiException(message: 'no', statusCode: 401),
      );
      expect(unauthorized.fold((f) => f, (_) => null), isA<AuthFailure>());
      final server = await apiCall<void>(
        () async => throw const ApiException(message: 'boom', statusCode: 500),
      );
      final f = server.fold((f) => f, (_) => null);
      expect(f, isA<ServerFailure>());
      expect(f!.displayMessage, 'boom');
    });

    test('DioException mapping is unchanged', () async {
      final result = await apiCall<void>(
        () async => throw DioException(requestOptions: RequestOptions()),
      );
      expect(result.fold((f) => f, (_) => null), isA<NetworkFailure>());
    });
  });

  group('FailureX.displayMessage for ParseFailure', () {
    test('with path', () {
      expect(
        const Failure.parse(path: 'A.b').displayMessage,
        "Komodo returned data this app version can't read (A.b). "
        'Please update the app or report this.',
      );
    });
    test('without path', () {
      expect(
        const Failure.parse().displayMessage,
        "Komodo returned data this app version can't read. "
        'Please update the app or report this.',
      );
    });
  });
}
