import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';

void main() {
  group('KomodoCoreVersion', () {
    test(
      'parses prefixed versions and preserves the reported display value',
      () {
        final version = KomodoCoreVersion.parse('v2.3.1-beta.1');

        expect(version.display, 'v2.3.1-beta.1');
        expect(version.isParsed, isTrue);
        expect(version.isAtLeast(2, 3, 0), isTrue);
      },
    );

    test('treats malformed versions conservatively', () {
      final version = KomodoCoreVersion.parse('development');

      expect(version.isParsed, isFalse);
      expect(
        KomodoApiCapabilities.fromVersion(version).isLegacyV22,
        isTrue,
      );
    });
  });

  group('KomodoApiCapabilities', () {
    test('selects the 2.2 API surface', () {
      final capabilities = KomodoApiCapabilities.fromVersion(
        KomodoCoreVersion.parse('2.2.0'),
      );

      expect(capabilities.isLegacyV22, isTrue);
      expect(capabilities.supportsPaginatedResourceLists, isFalse);
      expect(capabilities.supportsMultipleServerBuilders, isFalse);
      expect(capabilities.supportsDeploymentCustomName, isFalse);
      expect(capabilities.supportsActionCancellation, isFalse);
      expect(
        capabilities.encodeResourceTarget(type: 'Stack', id: 'stack-1'),
        <String, dynamic>{'type': 'Stack', 'id': 'stack-1'},
      );
      expect(capabilities.listContainersRpc, 'ListDockerContainers');
      expect(capabilities.listNetworksRpc, 'ListDockerNetworks');
      expect(
        capabilities.listRegistryAccountsRpc,
        'ListDockerRegistryAccounts',
      );
      expect(
        capabilities.createRegistryAccountRpc,
        'CreateDockerRegistryAccount',
      );
      expect(
        capabilities.updateRegistryAccountRpc,
        'UpdateDockerRegistryAccount',
      );
      expect(
        capabilities.deleteRegistryAccountRpc,
        'DeleteDockerRegistryAccount',
      );
    });

    test('selects the 2.3+ API surface', () {
      final capabilities = KomodoApiCapabilities.fromVersion(
        KomodoCoreVersion.parse('2.4.0'),
      );

      expect(capabilities.isLegacyV22, isFalse);
      expect(capabilities.supportsPaginatedResourceLists, isTrue);
      expect(capabilities.supportsMultipleServerBuilders, isTrue);
      expect(capabilities.supportsDeploymentCustomName, isTrue);
      expect(capabilities.supportsActionCancellation, isTrue);
      expect(
        capabilities.encodeResourceTarget(type: 'Stack', id: 'stack-1'),
        <String, dynamic>{'type': 'Stack', 'id': 'stack-1'},
      );
      expect(capabilities.listContainersRpc, 'ListContainers');
      expect(capabilities.listNetworksRpc, 'ListNetworks');
      expect(
        capabilities.listRegistryAccountsRpc,
        'ListImageRegistryAccounts',
      );
    });
  });
}
