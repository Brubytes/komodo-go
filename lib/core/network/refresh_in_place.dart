import 'package:flutter/foundation.dart';

/// Fetches fresh data and applies it only when it differs from [current].
///
/// Unlike `ref.invalidate`, an unchanged poll result causes no state change,
/// so watchers do not rebuild (and no loading -> data flicker). Fetch errors
/// are swallowed: the previous value stays and the next tick is the retry.
///
/// Returns `true` when [apply] was called.
Future<bool> refreshInPlace<T>({
  required T? current,
  required Future<T> Function() fetch,
  required void Function(T value) apply,
  bool Function(T a, T b)? equals,
  bool Function()? isMounted,
}) async {
  final T next;
  try {
    next = await fetch();
  } on Object {
    return false;
  }
  if (isMounted != null && !isMounted()) return false;
  if (current != null && (equals?.call(current, next) ?? current == next)) {
    return false;
  }
  apply(next);
  return true;
}

/// Element-wise list equality (elements compared with `==`).
bool listEq<T>(List<T> a, List<T> b) => listEquals(a, b);
