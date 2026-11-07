import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stacks_filters_provider.g.dart';

@riverpod
class StacksPendingUpdateFilter extends _$StacksPendingUpdateFilter {
  @override
  bool build() => false;

  bool get enabled => state;

  set enabled(bool value) => state = value;
}
