import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart';

ProviderContainer createProviderContainer({
  List<Override> overrides = const [],
  Duration? Function(int retryCount, Object error)? retry,
}) {
  return ProviderContainer(
    overrides: overrides,
    // Disable retries in tests to surface errors immediately.
    retry: retry ?? _noRetry,
  );
}

Duration? _noRetry(int retryCount, Object error) => null;

ProviderSubscription<AsyncValue<T>> listenProvider<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) {
  return container.listen(provider, (previous, next) {}, fireImmediately: true);
}

Future<T> readAsyncProvider<T>(
  ProviderContainer container,
  ProviderListenable<Future<T>> provider,
) {
  return container.read(provider);
}

void expectAsyncError<T>(AsyncValue<T> value) {
  expect(value.hasError, isTrue);
}
