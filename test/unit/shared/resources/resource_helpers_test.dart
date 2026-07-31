import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_option.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';
import 'package:komodo_go/shared/resources/resource_helpers.dart';

void main() {
  group('ResourceKindX', () {
    test('maps Komodo variants without changing existing spellings', () {
      expect(ResourceKindX.fromVariant('Server'), ResourceKind.servers);
      expect(ResourceKindX.fromVariant('ResourceSync'), ResourceKind.syncs);
      expect(ResourceKindX.fromVariant('resource_sync'), ResourceKind.syncs);
      expect(ResourceKindX.fromVariant('unknown'), ResourceKind.unknown);
    });

    test('keeps canonical Komodo variants', () {
      expect(ResourceKind.servers.variant, 'Server');
      expect(ResourceKind.syncs.variant, 'ResourceSync');
      expect(ResourceKind.builders.variant, 'Builder');
      expect(ResourceKind.unknown.variant, 'Resource');
    });
  });

  group('ResourceRef', () {
    test('builds stable lowercase keys from kind and trimmed id', () {
      const ref = ResourceRef(kind: ResourceKind.deployments, id: ' abc ');
      expect(ref.key, 'deployment:abc');
    });

    test('can parse existing alerter target key shape', () {
      expect(
        ResourceRef.tryParseKey('Stack:stack-id'),
        const ResourceRef(kind: ResourceKind.stacks, id: 'stack-id'),
      );
      expect(ResourceRef.tryParseKey('broken'), isNull);
      expect(ResourceRef.tryParseKey('Server:'), isNull);
    });
  });

  group('ResourceOption', () {
    test('exposes the existing target key shape', () {
      const option = ResourceOption(
        ref: ResourceRef(kind: ResourceKind.actions, id: 'act-1'),
        name: 'Deploy',
      );

      expect(option.variant, 'Action');
      expect(option.key, 'action:act-1');
    });
  });

  group('resource helpers', () {
    test('resourceIcon keeps existing icon mapping', () {
      expect(resourceIcon(ResourceKind.servers), AppIcons.server);
      expect(resourceIcon(ResourceKind.syncs), AppIcons.syncs);
      expect(resourceIcon(ResourceKind.unknown), AppIcons.widgets);
    });

    test('resourceLabel prefers direct name, lookup name, then short fallback', () {
      expect(
        resourceLabel(
          ref: const ResourceRef(kind: ResourceKind.builds, id: 'build-1'),
          directName: '  Web ',
          lookup: const {},
        ),
        'Web',
      );
      expect(
        resourceLabel(
          ref: const ResourceRef(kind: ResourceKind.builds, id: 'build-1'),
          lookup: const {'build:build-1': 'API'},
        ),
        'API',
      );
      expect(
        resourceLabel(
          ref: const ResourceRef(
            kind: ResourceKind.builds,
            id: '1234567890abcdef',
          ),
          lookup: const {},
        ),
        'Build 123456...cdef',
      );
    });
  });
}
