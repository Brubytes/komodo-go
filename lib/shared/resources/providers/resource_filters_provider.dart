import 'package:komodo_go/core/widgets/filters/template_filter.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'resource_filters_provider.g.dart';

/// Search query for a resource list, keyed by [ResourceKind].
@riverpod
class ResourceSearchQuery extends _$ResourceSearchQuery {
  @override
  String build(ResourceKind kind) => '';

  String get query => state;

  set query(String value) => state = value;
}

/// Selected tag filter for a resource list, keyed by [ResourceKind].
@riverpod
class ResourceTagFilter extends _$ResourceTagFilter {
  @override
  Set<String> build(ResourceKind kind) => <String>{};

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

/// Template filter mode for a resource list, keyed by [ResourceKind].
@riverpod
class ResourceTemplateFilterState extends _$ResourceTemplateFilterState {
  @override
  TemplateFilter build(ResourceKind kind) => TemplateFilter.exclude;

  TemplateFilter get value => state;

  set value(TemplateFilter next) => state = next;
}
