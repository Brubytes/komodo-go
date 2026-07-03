import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/composition/resources/resource_catalog_provider.dart'
    as catalog;
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_option.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';

void main() {
  group('ResourceOption ordering contract', () {
    test('sorts by variant then name exactly like the existing sheet', () {
      final options = [
        const ResourceOption(
          ref: ResourceRef(kind: ResourceKind.servers, id: 'srv-b'),
          name: 'Zulu',
        ),
        const ResourceOption(
          ref: ResourceRef(kind: ResourceKind.actions, id: 'act-a'),
          name: 'Beta',
        ),
        const ResourceOption(
          ref: ResourceRef(kind: ResourceKind.actions, id: 'act-b'),
          name: 'Alpha',
        ),
      ]..sort((a, b) {
          final typeSort = a.variant.compareTo(b.variant);
          if (typeSort != 0) return typeSort;
          return a.name.compareTo(b.name);
        });

      expect(options.map((option) => option.key), [
        'action:act-b',
        'action:act-a',
        'server:srv-b',
      ]);
    });

    test('exposes the composed resource options provider', () {
      expect(catalog.resourceOptionsProvider, isNotNull);
    });
  });
}
