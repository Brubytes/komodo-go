import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/async/async_value_x.dart';

void main() {
  final stack = StackTrace.current;
  const first = AsyncLoading<int>();
  const data = AsyncData<int>(1);
  final refreshing = asyncWithPrevious<int>(const AsyncLoading(), data);
  final reloading = asyncWithPrevious<int>(
    const AsyncLoading(),
    data,
    isRefresh: false,
  );
  final staleError = asyncWithPrevious<int>(AsyncError('boom', stack), data);
  final firstError = AsyncError<int>('boom', stack);

  test('classifies states', () {
    expect(first.isFirstLoad, isTrue);
    expect(data.isFirstLoad, isFalse);
    expect(refreshing.isBackgroundRefresh, isTrue);
    expect(reloading.isBackgroundRefresh, isTrue);
    expect(refreshing.isRefreshing, isTrue);
    expect(reloading.isReloading, isTrue);
    expect(data.isBackgroundRefresh, isFalse);
    expect(staleError.hasStaleError, isTrue);
    expect(staleError.value, 1);
    expect(firstError.hasStaleError, isFalse);
    expect(firstError.hasBlockingError, isTrue);
  });

  test('whenStale never swaps data for loading or error', () {
    String render(AsyncValue<int> v) => v.whenStale(
      data: (d) => 'data $d',
      loading: () => 'loading',
      error: (e, _) => 'error',
    );
    expect(render(first), 'loading');
    expect(render(data), 'data 1');
    expect(render(refreshing), 'data 1');
    expect(render(reloading), 'data 1');
    expect(render(staleError), 'data 1');
    expect(render(firstError), 'error');
  });

  test('whenStale staleError callback takes over for stale errors', () {
    final out = staleError.whenStale(
      data: (d) => 'data',
      loading: () => 'loading',
      error: (e, _) => 'error',
      staleError: (d, e, _) => 'stale $d $e',
    );
    expect(out, 'stale 1 boom');
  });

  test('LastAsyncValue keeps the previous value while a new one loads', () {
    final holder = LastAsyncValue<int>();
    expect(holder.resolve(first).isFirstLoad, isTrue);
    expect(holder.resolve(data).value, 1);
    final during = holder.resolve(first);
    expect(during.value, 1);
    expect(during.isRefreshing, isTrue);
    expect(holder.resolve(firstError).hasError, isTrue);
  });
}
