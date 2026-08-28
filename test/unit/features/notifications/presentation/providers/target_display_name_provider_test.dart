import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/presentation/providers/target_display_name_provider.dart';
import 'package:komodo_go/shared/resources/providers/resource_name_resolver_provider.dart';

void main() {
  test('an unresolved generic fallback is not cached', () async {
    const target = ResourceTarget(
      type: ResourceTargetType.server,
      id: 'server-1',
    );
    var resolvesName = false;
    final root = ProviderContainer(
      overrides: [
        resourceNameResolverProvider.overrideWith(
          (ref) =>
              (resource) async => resolvesName ? 'local' : null,
        ),
      ],
    );
    addTearDown(root.dispose);
    root.read(activeConnectionProvider.notifier).active = ActiveConnectionData(
      connectionId: 'connection-1',
      name: 'Test',
      credentials: const ApiCredentials(
        baseUrl: 'https://example.test',
        apiKey: 'key',
        apiSecret: 'secret',
      ),
      coreVersion: KomodoCoreVersion.parse('2.3.1'),
    );

    expect(await root.read(targetDisplayNameProvider(target).future), 'Server');

    resolvesName = true;
    root.invalidate(targetDisplayNameProvider(target));
    expect(
      await root.read(targetDisplayNameProvider(target).future),
      'local',
    );
  });
}
