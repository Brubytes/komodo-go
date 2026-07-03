import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/shared/resources/providers/resource_action_executor.dart';

class _FakeRepo {}

class _Host with ResourceActionExecutor<_FakeRepo> {
  _Host({_FakeRepo? repo}) : _repo = repo;

  final _FakeRepo? _repo;
  bool mountedFlag = true;
  int invalidations = 0;

  @override
  AsyncValue<void> state = const AsyncValue.data(null);

  @override
  _FakeRepo? readRepository() => _repo;

  @override
  void invalidateList() => invalidations++;

  @override
  bool get isMounted => mountedFlag;
}

void main() {
  group('executeAction', () {
    test('returns true, resets state, invalidates list on success', () async {
      final host = _Host(repo: _FakeRepo());

      final ok = await host.executeAction((repo) async => const Right(null));

      expect(ok, isTrue);
      expect(host.state.hasError, isFalse);
      expect(host.state.isLoading, isFalse);
      expect(host.invalidations, 1);
    });

    test('returns false and surfaces failure message on Left', () async {
      final host = _Host(repo: _FakeRepo());

      final ok = await host.executeAction(
        (repo) async => const Left(Failure.server(message: 'boom')),
      );

      expect(ok, isFalse);
      expect(host.state.hasError, isTrue);
      expect(host.invalidations, 0);
    });

    test('returns false with auth error when repository is null', () async {
      final host = _Host();

      final ok = await host.executeAction((repo) async => const Right(null));

      expect(ok, isFalse);
      expect(host.state.hasError, isTrue);
      expect(host.state.error, 'Not authenticated');
    });

    test('bails out without touching state when unmounted mid-flight',
        () async {
      final host = _Host(repo: _FakeRepo());

      final ok = await host.executeAction((repo) async {
        host.mountedFlag = false;
        return const Right(null);
      });

      expect(ok, isFalse);
      expect(host.state.isLoading, isTrue);
      expect(host.invalidations, 0);
    });
  });

  group('executeRequest', () {
    test('returns the value and invalidates list on success', () async {
      final host = _Host(repo: _FakeRepo());

      final value = await host.executeRequest<int>(
        (repo) async => const Right(42),
      );

      expect(value, 42);
      expect(host.invalidations, 1);
    });

    test('returns null and surfaces failure on Left', () async {
      final host = _Host(repo: _FakeRepo());

      final value = await host.executeRequest<int>(
        (repo) async => const Left(Failure.server(message: 'boom')),
      );

      expect(value, isNull);
      expect(host.state.hasError, isTrue);
      expect(host.invalidations, 0);
    });

    test('returns null with auth error when repository is null', () async {
      final host = _Host();

      final value = await host.executeRequest<int>(
        (repo) async => const Right(42),
      );

      expect(value, isNull);
      expect(host.state.error, 'Not authenticated');
    });
  });
}
