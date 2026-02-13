import 'dart:async';

import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'target_name_cache_provider.g.dart';

@Riverpod(keepAlive: true)
class TargetNameCache extends _$TargetNameCache {
  final Map<String, Completer<String>> _inflight =
      <String, Completer<String>>{};

  @override
  Map<String, String> build() {
    ref.listen<ActiveConnectionData?>(activeConnectionProvider, (_, _) {
      _inflight.clear();
    });

    return <String, String>{};
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
    state = {
      ...state,
      _key(connectionId: connectionId, target: target): name.trim(),
    };
  }

  Future<String> getOrFetch({
    required String connectionId,
    required ResourceTarget target,
    required Future<String> Function() fetch,
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
      if (name.trim().isNotEmpty) {
        state = {...state, key: name.trim()};
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
