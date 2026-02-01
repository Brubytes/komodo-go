import 'package:komodo_go/core/widgets/filters/template_filter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'servers_filters_provider.g.dart';

@riverpod
class ServersSearchQuery extends _$ServersSearchQuery {
  @override
  String build() => '';

  String get query => state;

  set query(String value) => state = value;
}

@riverpod
class ServersTagFilter extends _$ServersTagFilter {
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
class ServersTemplateFilterState extends _$ServersTemplateFilterState {
  @override
  TemplateFilter build() => TemplateFilter.exclude;

  TemplateFilter get value => state;

  set value(TemplateFilter next) => state = next;
}
