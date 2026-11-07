import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Refreshable;

/// Refreshes [targets] and completes when all of them have finished
/// (successfully or not), for `RefreshIndicator.onRefresh`.
///
/// `onRefresh: () async { ref.invalidate(x); }` completes immediately, so the
/// indicator disappears before any data arrives. This helper refreshes each
/// provider (keeping its previous value, see `AsyncValue.isRefreshing`) and
/// awaits the new futures. Errors are swallowed: they surface through the
/// provider state (stale banner / error view), not as thrown exceptions.
///
/// Pass the `.future` of generated providers; families included:
/// ```dart
/// RefreshIndicator(
///   onRefresh: () => refreshProviders(ref, [
///     stackDetailProvider(id).future,
///     stackServicesProvider(id).future,
///   ]),
///   child: ...,
/// )
/// ```
/// For notifier providers use `fooProvider.future` as well.
Future<void> refreshProviders(
  WidgetRef ref,
  Iterable<Refreshable<Future<Object?>>> targets,
) async {
  final pending = <Future<void>>[];
  for (final target in targets) {
    try {
      pending.add(_ignoreErrors(ref.refresh(target)));
    } on Object {
      // A provider that throws synchronously must not abort the others.
    }
  }
  await Future.wait(pending);
}

Future<void> _ignoreErrors(Future<Object?> future) async {
  try {
    await future;
  } on Object {
    // Reported through the provider's AsyncValue.
  }
}
