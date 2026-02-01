import 'package:komodo_go/core/widgets/filters/template_filter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'builds_filters_provider.g.dart';

@riverpod
class BuildsSearchQuery extends _$BuildsSearchQuery {
  @override
  String build() => '';

  String get query => state;

  set query(String value) => state = value;
}

@riverpod
class BuildsTagFilter extends _$BuildsTagFilter {
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
class BuildsTemplateFilterState extends _$BuildsTemplateFilterState {
  @override
  TemplateFilter build() => TemplateFilter.exclude;

  TemplateFilter get value => state;

  set value(TemplateFilter next) => state = next;
}
