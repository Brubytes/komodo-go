import 'package:komodo_go/shared/resources/resource_sorting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'resource_view_prefs_provider.g.dart';

/// Session-scoped sort/quick-filter state for a resource list.
///
/// Keyed by a list id (e.g. `'stacks'`). All providers are `keepAlive` so the
/// choice survives navigating away and back within the session; nothing is
/// persisted to disk.
@Riverpod(keepAlive: true)
class ResourceSortModeState extends _$ResourceSortModeState {
  @override
  ResourceSortMode build(String listId) => ResourceSortMode.problemsFirst;

  ResourceSortMode get mode => state;

  set mode(ResourceSortMode value) => state = value;
}

/// "Problems only" quick filter (severity <= warning).
@Riverpod(keepAlive: true)
class ResourceProblemsOnly extends _$ResourceProblemsOnly {
  @override
  bool build(String listId) => false;

  bool get enabled => state;

  set enabled(bool value) => state = value;
}

/// Selected state labels for a resource list.
@Riverpod(keepAlive: true)
class ResourceStateFilter extends _$ResourceStateFilter {
  @override
  Set<String> build(String listId) => <String>{};

  Set<String> get selected => state;

  set selected(Set<String> value) => state = Set<String>.of(value);

  void toggle(String label) {
    final next = Set<String>.of(state);
    if (!next.remove(label)) next.add(label);
    state = next;
  }

  void clear() => state = <String>{};
}

/// Selected server names for a resource list.
@Riverpod(keepAlive: true)
class ResourceServerFilter extends _$ResourceServerFilter {
  @override
  Set<String> build(String listId) => <String>{};

  Set<String> get selected => state;

  set selected(Set<String> value) => state = Set<String>.of(value);

  void toggle(String name) {
    final next = Set<String>.of(state);
    if (!next.remove(name)) next.add(name);
    state = next;
  }

  void clear() => state = <String>{};
}
