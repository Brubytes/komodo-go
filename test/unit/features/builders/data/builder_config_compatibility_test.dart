import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/features/builders/data/builder_config_compatibility.dart';

void main() {
  group('builder config compatibility', () {
    test('serializes one server_id for Komodo 2.2', () {
      final result = serializeServerBuilderConfig(
        current: const <String, dynamic>{
          'server_ids': <String>['old'],
          'servers': <String>['stale'],
        },
        serverIdsText: 'server-a, server-b',
        capabilities: KomodoApiCapabilities.v22,
      );

      expect(result, <String, dynamic>{'server_id': 'server-a'});
    });

    test('serializes server_ids for Komodo 2.3+', () {
      final result = serializeServerBuilderConfig(
        current: const <String, dynamic>{'server_id': 'old'},
        serverIdsText: 'server-a, server-b',
        capabilities: KomodoApiCapabilities.v23AndNewer,
      );

      expect(result, <String, dynamic>{
        'server_ids': <String>['server-a', 'server-b'],
      });
    });

    test('uses docker_registries for Komodo 2.2 AWS builders', () {
      final result = serializeAwsRegistryFields(
        current: const <String, dynamic>{
          'image_registries': <String>['docker.io'],
        },
        capabilities: KomodoApiCapabilities.v22,
      );

      expect(result, <String, dynamic>{
        'docker_registries': <String>['docker.io'],
      });
    });

    test('uses image_registries for Komodo 2.3+ AWS builders', () {
      final result = serializeAwsRegistryFields(
        current: const <String, dynamic>{
          'docker_registries': <String>['ghcr.io'],
        },
        capabilities: KomodoApiCapabilities.v23AndNewer,
      );

      expect(result, <String, dynamic>{
        'image_registries': <String>['ghcr.io'],
      });
    });
  });
}
