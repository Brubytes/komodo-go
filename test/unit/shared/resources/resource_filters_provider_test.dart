import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/widgets/filters/template_filter.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/providers/resource_filters_provider.dart';

import '../../../support/provider_test_templates.dart';

void main() {
  group('resourceSearchQueryProvider', () {
    test('starts empty, updates via query setter, isolated per kind', () {
      final container = createProviderContainer();
      addTearDown(container.dispose);
      final buildsSub = container.listen(
        resourceSearchQueryProvider(ResourceKind.builds),
        (previous, next) {},
      );
      addTearDown(buildsSub.close);
      final reposSub = container.listen(
        resourceSearchQueryProvider(ResourceKind.repos),
        (previous, next) {},
      );
      addTearDown(reposSub.close);

      expect(
        container.read(resourceSearchQueryProvider(ResourceKind.builds)),
        '',
      );

      container
          .read(resourceSearchQueryProvider(ResourceKind.builds).notifier)
          .query = 'api';

      expect(
        container.read(resourceSearchQueryProvider(ResourceKind.builds)),
        'api',
      );
      expect(
        container
            .read(resourceSearchQueryProvider(ResourceKind.builds).notifier)
            .query,
        'api',
      );
      // Other kinds are independent.
      expect(
        container.read(resourceSearchQueryProvider(ResourceKind.repos)),
        '',
      );
    });
  });

  group('resourceTagFilterProvider', () {
    test('toggle adds/removes, selected replaces, clear resets', () {
      final container = createProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(
        resourceTagFilterProvider(ResourceKind.syncs),
        (previous, next) {},
      );
      addTearDown(sub.close);

      final notifier = container.read(
        resourceTagFilterProvider(ResourceKind.syncs).notifier,
      );

      expect(
        container.read(resourceTagFilterProvider(ResourceKind.syncs)),
        isEmpty,
      );

      notifier.toggle('t1');
      expect(
        container.read(resourceTagFilterProvider(ResourceKind.syncs)),
        {'t1'},
      );

      notifier.toggle('t1');
      expect(
        container.read(resourceTagFilterProvider(ResourceKind.syncs)),
        isEmpty,
      );

      notifier.selected = {'a', 'b'};
      expect(
        container.read(resourceTagFilterProvider(ResourceKind.syncs)),
        {'a', 'b'},
      );

      notifier.clear();
      expect(
        container.read(resourceTagFilterProvider(ResourceKind.syncs)),
        isEmpty,
      );
    });
  });

  group('resourceTemplateFilterStateProvider', () {
    test('defaults to exclude and updates via value setter', () {
      final container = createProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(
        resourceTemplateFilterStateProvider(ResourceKind.procedures),
        (previous, next) {},
      );
      addTearDown(sub.close);

      expect(
        container.read(
          resourceTemplateFilterStateProvider(ResourceKind.procedures),
        ),
        TemplateFilter.exclude,
      );

      container
          .read(
            resourceTemplateFilterStateProvider(ResourceKind.procedures)
                .notifier,
          )
          .value = TemplateFilter.only;

      expect(
        container.read(
          resourceTemplateFilterStateProvider(ResourceKind.procedures),
        ),
        TemplateFilter.only,
      );
    });
  });
}
