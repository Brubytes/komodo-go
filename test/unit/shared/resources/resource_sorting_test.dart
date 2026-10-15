import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/composition/containers/containers_view.dart';
import 'package:komodo_go/core/widgets/filters/template_filter.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/shared/resources/resource_sorting.dart';

class _Item {
  const _Item(this.name, this.severity, {this.updatedAt = 0, this.state = ''});

  final String name;
  final int severity;
  final int updatedAt;
  final String state;
}

List<String> _names(List<_Item> items) => [for (final i in items) i.name];

List<_Item> _sort(List<_Item> items, ResourceSortMode mode) => sortResources(
  items,
  mode: mode,
  severityOf: (i) => i.severity,
  nameOf: (i) => i.name,
  updatedAtOf: (i) => i.updatedAt,
);

void main() {
  const items = [
    _Item('zeta', 2, updatedAt: 5),
    _Item('Alpha', 2, updatedAt: 9),
    _Item('broken', 0, updatedAt: 1),
    _Item('stopped', 3, updatedAt: 7),
    _Item('Updating', 1, updatedAt: 3),
    _Item('also-broken', 0, updatedAt: 2),
  ];

  group('sortResources', () {
    test('computes sort keys once per item and keeps input untouched', () {
      var nameCalls = 0;
      final input = List<_Item>.of(items);
      final sorted = sortResources<_Item>(
        input,
        mode: ResourceSortMode.name,
        severityOf: (i) => i.severity,
        nameOf: (i) {
          nameCalls++;
          return i.name;
        },
      );
      expect(nameCalls, items.length);
      expect(input, items);
      expect(_names(sorted), [
        'Alpha',
        'also-broken',
        'broken',
        'stopped',
        'Updating',
        'zeta',
      ]);
    });

    test('problems first orders by severity then case-insensitive name', () {
      expect(
        _names(_sort(items, ResourceSortMode.problemsFirst)),
        ['also-broken', 'broken', 'Updating', 'Alpha', 'zeta', 'stopped'],
      );
    });

    test('name ignores severity and case', () {
      expect(
        _names(_sort(items, ResourceSortMode.name)),
        ['Alpha', 'also-broken', 'broken', 'stopped', 'Updating', 'zeta'],
      );
    });

    test('recently updated sorts newest first', () {
      expect(
        _names(_sort(items, ResourceSortMode.recentlyUpdated)),
        ['Alpha', 'stopped', 'zeta', 'Updating', 'also-broken', 'broken'],
      );
    });

    test('recently updated falls back to problems first without timestamp', () {
      final sorted = sortResources<_Item>(
        items,
        mode: ResourceSortMode.recentlyUpdated,
        severityOf: (i) => i.severity,
        nameOf: (i) => i.name,
      );
      expect(_names(sorted).first, 'also-broken');
    });

    test('does not mutate the input list', () {
      final input = List<_Item>.of(items);
      _sort(input, ResourceSortMode.name);
      expect(_names(input), _names(items));
    });
  });

  group('applyResourceViewFilters', () {
    const stateful = [
      _Item('a', 0, state: 'Failed'),
      _Item('b', 1, state: 'Building'),
      _Item('c', 2, state: 'Ok'),
      _Item('d', 3, state: 'Unknown'),
    ];

    List<_Item> apply({
      bool problemsOnly = false,
      Set<String> states = const {},
    }) => applyResourceViewFilters<_Item>(
      stateful,
      problemsOnly: problemsOnly,
      selectedStates: states,
      selectedServers: const {},
      severityOf: (i) => i.severity,
      stateLabelOf: (i) => i.state,
    );

    test('problems only keeps severity <= warning', () {
      expect(_names(apply(problemsOnly: true)), ['a', 'b']);
    });

    test('state filter is multi-select', () {
      expect(_names(apply(states: {'Ok', 'Unknown'})), ['c', 'd']);
    });

    test('server filter uses serverNameOf', () {
      final result = applyResourceViewFilters<String>(
        ['nas:a', 'vps:b', 'nas:c'],
        problemsOnly: false,
        selectedStates: const {},
        selectedServers: const {'nas'},
        severityOf: (_) => 2,
        serverNameOf: (i) => i.split(':').first,
      );
      expect(result, ['nas:a', 'nas:c']);
    });
  });

  group('countActiveResourceFilters', () {
    test('defaults count as zero (template exclude is default)', () {
      expect(countActiveResourceFilters(), 0);
    });

    test('template include/only count as one each', () {
      expect(
        countActiveResourceFilters(templateFilter: TemplateFilter.include),
        1,
      );
      expect(
        countActiveResourceFilters(templateFilter: TemplateFilter.only),
        1,
      );
    });

    test('sums query, tags, quick filters and extras', () {
      expect(
        countActiveResourceFilters(
          query: ' nginx ',
          selectedTags: {'a', 'b'},
          templateFilter: TemplateFilter.only,
          problemsOnly: true,
          selectedStates: {'Failed'},
          selectedServers: {'nas'},
          extra: 1,
        ),
        1 + 2 + 1 + 1 + 1 + 1 + 1,
      );
    });

    test('blank query is not counted', () {
      expect(countActiveResourceFilters(query: '   '), 0);
    });
  });

  group('resourceStateLabel', () {
    test('formats camelCase enum names', () {
      expect(resourceStateLabel(ServerStateLike.notOk), 'Not ok');
      expect(resourceStateLabel(BuildState.building), 'Building');
    });
  });

  group('severity of real state enums', () {
    test('container severity buckets', () {
      int sev(ContainerState state, {String? status}) => containerSeverity(
        ContainerListItem(name: 'c', state: state, status: status),
      );
      expect(sev(ContainerState.dead), ResourceSeverity.attention);
      expect(
        sev(ContainerState.exited, status: 'Exited (137) 2 hours ago'),
        ResourceSeverity.attention,
      );
      expect(
        sev(ContainerState.exited, status: 'Exited (0) 2 hours ago'),
        ResourceSeverity.inactive,
      );
      expect(sev(ContainerState.restarting), ResourceSeverity.warning);
      expect(sev(ContainerState.running), ResourceSeverity.healthy);
      expect(sev(ContainerState.paused), ResourceSeverity.inactive);
    });
  });
}

enum ServerStateLike { notOk }
