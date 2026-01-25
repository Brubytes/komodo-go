import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stacks_filters_provider.g.dart';

enum StacksTemplateFilter { exclude, include, only }

@riverpod
class StacksSearchQuery extends _$StacksSearchQuery {
  @override
  String build() => '';

  String get query => state;

  set query(String value) => state = value;
}

@riverpod
class StacksTagFilter extends _$StacksTagFilter {
  @override
  Set<String> build() => <String>{};

  Set<String> get selected => state;

  set selected(Set<String> value) => state = Set<String>.from(value);

  void toggle(String tag) {
    final next = Set<String>.from(state);
    if (next.contains(tag)) {
      next.remove(tag);
    } else {
      next.add(tag);
    }
    state = next;
  }

  void clear() => state = <String>{};
}

@riverpod
class StacksPendingUpdateFilter extends _$StacksPendingUpdateFilter {
  @override
  bool build() => false;

  bool get enabled => state;

  set enabled(bool value) => state = value;
}

@riverpod
class StacksTemplateFilterState extends _$StacksTemplateFilterState {
  @override
  StacksTemplateFilter build() => StacksTemplateFilter.exclude;

  StacksTemplateFilter get value => state;

  set value(StacksTemplateFilter next) => state = next;
}
