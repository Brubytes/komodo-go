import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';

typedef ResourceNameResolver = Future<String?> Function(ResourceRef ref);

final resourceNameResolverProvider = Provider<ResourceNameResolver>((ref) {
  return (resourceRef) async => null;
});
