import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deployments_filters_provider.g.dart';

@riverpod
class DeploymentsPendingUpdateFilter extends _$DeploymentsPendingUpdateFilter {
  @override
  bool build() => false;

  bool get enabled => state;

  set enabled(bool value) => state = value;
}
