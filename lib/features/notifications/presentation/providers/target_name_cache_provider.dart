import 'dart:async';
import 'dart:collection';

import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'target_name_cache_provider.g.dart';

/// Upper bound on cached names; the oldest entry is evicted first.
const int _maxCacheEntries = 500;

@Riverpod(keepAlive: true)
class TargetNameCache extends _$TargetNameCache {
  final Map<String, Completer<String>> _inflight =
      <String, Completer<String>>{};

  @override
  Map<String, String> build() {
    ref.listen<ActiveConnectionData?>(activeConnectionProvider, (_, _) {
      _inflight.clear();
      state = <String, String>{};
    });

    return <String, String>{};
  }

  /// Returns a copy of the current state with [key] set to [value] as the
  /// newest entry, evicting the oldest entries beyond [_maxCacheEntries].
  Map<String, String> _withEntry(String key, String value) {
    final next = LinkedHashMap<String, String>.of(state)
      ..remove(key)
      ..[key] = value;
    while (next.length > _maxCacheEntries) {
      next.remove(next.keys.first);
    }
    return next;
  }

  String? peek({required String connectionId, required ResourceTarget target}) {
    return state[_key(connectionId: connectionId, target: target)];
  }

  void put({
    required String connectionId,
    required ResourceTarget target,
    required String name,
  }) {
    if (name.trim().isEmpty) return;
    state = _withEntry(
      _key(connectionId: connectionId, target: target),
      name.trim(),
    );
  }

  Future<String> getOrFetch({
    required String connectionId,
    required ResourceTarget target,
    required Future<String> Function() fetch,
    bool Function(String name)? shouldCache,
  }) async {
    final key = _key(connectionId: connectionId, target: target);
    final cached = state[key];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final completer = Completer<String>();
    final existingInflight = _inflight.putIfAbsent(key, () => completer);
    if (!identical(existingInflight, completer)) {
      return existingInflight.future;
    }

    try {
      final name = await fetch();
      if (ref.mounted &&
          name.trim().isNotEmpty &&
          (shouldCache?.call(name) ?? true)) {
        state = _withEntry(key, name.trim());
      }
      completer.complete(name);
      return name;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _inflight.remove(key);
    }
  }
}

String _key({required String connectionId, required ResourceTarget target}) {
  return '$connectionId|${target.type.name}|${target.id}';
}
