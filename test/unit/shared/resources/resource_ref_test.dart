import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';
import 'package:komodo_go/shared/resources/providers/resource_name_resolver_provider.dart';

void main() {
  test('ResourceRef keys match the target name cache key shape', () {
    expect(
      const ResourceRef(kind: ResourceKind.stacks, id: 'stack-1').key,
      'stack:stack-1',
    );
    expect(
      const ResourceRef(kind: ResourceKind.syncs, id: 'sync-1').key,
      'resourcesync:sync-1',
    );
  });

  test('shared resource name resolver defaults to no resolved name', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final resolver = container.read(resourceNameResolverProvider);

    await expectLater(
      resolver(const ResourceRef(kind: ResourceKind.stacks, id: 'stack-1')),
      completion(isNull),
    );
  });
}
