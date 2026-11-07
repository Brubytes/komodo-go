import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Returns [next] carrying [previous]'s value (and keeping [next]'s loading
/// or error state), so `.value`, `isRefreshing`, `hasStaleError` etc. work.
///
/// Thin wrapper around Riverpod's `copyWithPrevious`, which is marked
/// `@internal` but is the only way to build such states by hand.
AsyncValue<T> asyncWithPrevious<T>(
  AsyncValue<T> next,
  AsyncValue<T> previous, {
  bool isRefresh = true,
}) {
  // Documented exception: no public API builds a refreshing/reloading state.
  // ignore: invalid_use_of_internal_member
  return next.copyWithPrevious(previous, isRefresh: isRefresh);
}

/// Stale-while-revalidate helpers for [AsyncValue].
///
/// Principle: once a value exists, never replace it with a spinner or an error
/// page. Only the very first load (no value) shows a skeleton; a background
/// refresh shows a thin progress bar; a failed refresh shows an inline banner.
///
/// Prefer `.value` over `.asData?.value` for reading data in UI: `.value`
/// keeps returning the previous value during reload and error-with-value,
/// while `.asData` returns null in both.
extension AsyncValueX<T> on AsyncValue<T> {
  /// Loading and nothing to show yet (initial load).
  bool get isFirstLoad => isLoading && !hasValue;

  /// A value is shown and a refresh or reload is running behind it.
  bool get isBackgroundRefresh => hasValue && isLoading;

  /// The latest fetch failed but an older value is still available.
  bool get hasStaleError => hasError && hasValue;

  /// The failure of a first load: error and nothing to show.
  bool get hasBlockingError => hasError && !hasValue;

  /// Like `AsyncValue.when` but never swaps existing data for [loading] or
  /// [error]: loading is skipped on refresh/reload and errors are skipped
  /// when a value exists. [data] therefore also receives the previous value
  /// while a refresh is running or after a failed refresh. Use [staleError]
  /// to render that case separately (it replaces [data] when set).
  R whenStale<R>({
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function() loading,
    R Function(T data, Object error, StackTrace stackTrace)? staleError,
  }) {
    if (staleError != null && hasStaleError) {
      return staleError(requireValue, this.error!, stackTrace!);
    }
    return when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      skipError: true,
      data: data,
      error: error,
      loading: loading,
    );
  }
}

/// Remembers the last value of an [AsyncValue] that was swapped for a new
/// provider instance (e.g. a family parameter change), so UIs can keep showing
/// the old data while the new instance loads.
///
/// Hold one per `State`, wrap the watched value with [resolve] in `build`:
/// ```dart
/// final _history = LastAsyncValue<Stats>();
/// final stats = _history.resolve(ref.watch(statsProvider(id, range)));
/// ```
/// While the new instance has no value, [resolve] returns an
/// `AsyncData(previous)` flagged `isLoading` (a refresh), so `.when` defaults
/// and `AsyncContent` keep the content and show a progress bar. If the new
/// instance fails before ever having a value, the previous value is kept and
/// the error is attached (a stale error), so the content stays with a retry
/// banner instead of being replaced by an error page. Not meant for
/// switches between unrelated entities (it would show the wrong data).
class LastAsyncValue<T> {
  AsyncValue<T>? _last;

  AsyncValue<T> resolve(AsyncValue<T> current) {
    if (current.hasValue) {
      _last = current;
      return current;
    }
    final last = _last;
    if (last == null || !last.hasValue) return current;
    if (current.isLoading) {
      return asyncWithPrevious(AsyncLoading<T>(), last);
    }
    if (current.hasError) return asyncWithPrevious(current, last);
    return current;
  }

  /// Forgets the remembered value (e.g. when switching to another entity).
  void clear() => _last = null;
}
