import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/widgets/filters/template_filter.dart';
import 'package:komodo_go/shared/resources/resource_list_filtering.dart';

class _Item {
  const _Item({
    required this.name,
    this.template = false,
    this.tags = const [],
    this.extraFields = const [],
  });

  final String name;
  final bool template;
  final List<String> tags;
  final List<String> extraFields;
}

List<_Item> _filter(
  List<_Item> items, {
  String query = '',
  Set<String> selectedTags = const {},
  TemplateFilter templateFilter = TemplateFilter.exclude,
  Map<String, String> tagNameById = const {},
}) {
  return applyResourceFilters<_Item>(
    items,
    query: query,
    selectedTags: selectedTags,
    templateFilter: templateFilter,
    tagNameById: tagNameById,
    isTemplate: (item) => item.template,
    tagsOf: (item) => item.tags,
    searchFieldsOf: (item) => [item.name, ...item.extraFields],
  );
}

void main() {
  group('applyResourceFilters', () {
    const plain = _Item(name: 'Alpha Api');
    const templated = _Item(name: 'Template Item', template: true);
    const tagged = _Item(name: 'Tagged', tags: ['t1', ' Prod ']);
    const withField = _Item(name: 'Fielded', extraFields: ['MainBranch']);

    test('excludes templates by default', () {
      expect(_filter([plain, templated]), [plain]);
    });

    test('include keeps templates, only keeps only templates', () {
      expect(
        _filter([plain, templated], templateFilter: TemplateFilter.include),
        [plain, templated],
      );
      expect(
        _filter([plain, templated], templateFilter: TemplateFilter.only),
        [templated],
      );
    });

    test('tag filter matches raw tag values case/whitespace-insensitively',
        () {
      expect(_filter([plain, tagged], selectedTags: {'T1'}), [tagged]);
      expect(_filter([plain, tagged], selectedTags: {'prod'}), [tagged]);
      expect(_filter([plain, tagged], selectedTags: {'other'}), isEmpty);
    });

    test('blank selected tags are ignored', () {
      expect(_filter([plain, tagged], selectedTags: {'  '}), [plain, tagged]);
    });

    test('query is trimmed and lowercased and matches any search field', () {
      expect(_filter([plain, withField], query: '  ALPHA '), [plain]);
      expect(_filter([plain, withField], query: 'mainbranch'), [withField]);
      expect(_filter([plain, withField], query: 'nothing'), isEmpty);
    });

    test('query matches display tag names resolved via tagNameById', () {
      const item = _Item(name: 'NoMatch', tags: ['tag-id-1']);
      expect(
        _filter(
          [item],
          query: 'backend',
          tagNameById: {'tag-id-1': 'Backend'},
        ),
        [item],
      );
      // Falls back to the raw tag value when unmapped.
      expect(_filter([item], query: 'tag-id-1'), [item]);
    });

    test('empty query keeps all remaining items', () {
      expect(_filter([plain, tagged]), [plain, tagged]);
    });
  });

  group('hasActiveResourceFilters', () {
    test('false for defaults (whitespace query, empty tags, exclude)', () {
      expect(
        hasActiveResourceFilters(
          query: '   ',
          selectedTags: const {},
          templateFilter: TemplateFilter.exclude,
        ),
        isFalse,
      );
    });

    test('true when any filter deviates from its default', () {
      expect(
        hasActiveResourceFilters(
          query: 'x',
          selectedTags: const {},
          templateFilter: TemplateFilter.exclude,
        ),
        isTrue,
      );
      expect(
        hasActiveResourceFilters(
          query: '',
          selectedTags: const {'t'},
          templateFilter: TemplateFilter.exclude,
        ),
        isTrue,
      );
      expect(
        hasActiveResourceFilters(
          query: '',
          selectedTags: const {},
          templateFilter: TemplateFilter.include,
        ),
        isTrue,
      );
    });
  });

  group('collectResourceTags', () {
    test('trims, dedupes, drops blanks, and sorts tags', () {
      const items = [
        _Item(name: 'a', tags: [' b ', 'a']),
        _Item(name: 'b', tags: ['b', '  ', 'c']),
      ];
      expect(
        collectResourceTags<_Item>(items, (item) => item.tags),
        ['a', 'b', 'c'],
      );
    });
  });

  group('resourceDisplayTags', () {
    test('maps ids to names with raw fallback, preserving item order', () {
      expect(
        resourceDisplayTags(['id1', 'raw'], {'id1': 'Name One'}),
        ['Name One', 'raw'],
      );
      expect(resourceDisplayTags(const [], const {}), isEmpty);
    });
  });
}
