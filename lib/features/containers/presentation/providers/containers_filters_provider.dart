import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'containers_filters_provider.g.dart';

@riverpod
class ContainersSearchQuery extends _$ContainersSearchQuery {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

@riverpod
class ContainersServerFilter extends _$ContainersServerFilter {
  @override
  String? build() => null;

  void setServerId(String? value) => state = value;
}
