# Resource List Dedup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract one generic, tested resource-list foundation (filter state, filter logic, list scaffold) and migrate the five copy-pasted list features — builds, repos, actions, procedures, syncs — onto it, behavior-preserved, removing ~2,700 duplicated handwritten lines.

**Architecture:** Pure filter functions live in `lib/shared/resources/resource_list_filtering.dart` (unit-testable, no Flutter/Riverpod deps); per-screen filter state becomes three `@riverpod` family notifiers keyed by a new `ResourceKind` enum in `lib/shared/resources/providers/resource_filters_provider.dart` (one codegen unit replaces five identical files, and family members are autoDispose per key — the same reset-on-navigate-away lifecycle the current per-feature autoDispose providers have). A generic `ResourceListView<T>` widget in `lib/core/widgets/resource_list/` renders all shared chrome (app bar, search, filters panel, tag sheet, skeletons, empty/error states, pull-to-refresh, busy overlay) and takes a `ResourceListConfig<T>` object holding everything that differs per feature: title/icon/color/keys/copy, provider callbacks (`watchList`/`refreshList`/`invalidateList`/`watchActionsState` — plain typed closures, so no coupling to generated provider types), item extractors (`isTemplate`/`tagsOf`/`searchFieldsOf`), and a `cardBuilder` closure that owns per-feature navigation and action handling. Each feature's `<f>s_list_view.dart` shrinks to a ~80-line file: the existing public view class (router untouched) plus its config. Finally, the five identical `_executeAction`/`_executeRequest` bodies in the `*Actions` notifiers are extracted into a `ResourceActionExecutor<RepoT>` mixin.

**Tech Stack:** Flutter 3.38.9 via FVM, Riverpod v3 with `riverpod_annotation` codegen (family class-based notifiers — same pattern as existing `StackUpdates`), freezed models (unchanged), fpdart `Either` (unchanged), `flutter_test` + `mocktail`, `very_good_analysis` lints.

## Global Constraints

- Prefix every Flutter/Dart command with `fvm` (e.g. `fvm flutter test`, `fvm flutter analyze`); the SDK is pinned via `.fvmrc`.
- Behavior preservation is the acceptance bar: identical widget tree shape, filter semantics, refresh targets, animations (`AppFadeSlide` stagger, `AnimatedSwitcher` with `AppMotion` curves), `skipLoadingOnRefresh`/`skipLoadingOnReload`, and busy overlay for all five screens. The ONLY deliberate normalization: the loading skeleton `ListView.separated` gets `shrinkWrap: true, physics: NeverScrollableScrollPhysics()` for all five (builds already has it at `builds_list_view.dart:542-543`; the other four nest an unconstrained `ListView` inside the outer `ListView` — a latent unbounded-height layout error on first load).
- Preserve these ValueKeys exactly (they are created by the list views): `ValueKey('builds_search')`, `ValueKey('repos_search')`, `ValueKey('actions_search')`, `ValueKey('procedures_search')`, `ValueKey('syncs_search')`.
- Do NOT touch the card widgets (`build_card.dart`, `repo_card.dart`, `action_card.dart`, `procedure_card.dart`, `sync_card.dart`) — Patrol flows in `integration_test/resource_flows/` depend on their keys (`build_card_<id>`, `build_card_menu_<id>`, `build_card_run_<id>`, `build_card_cancel_<id>`, and analogous per feature), their icons (`AppIcons.play`, `AppIcons.moreVertical`), and `find.text(<resource name>)` on cards.
- Preserve these shared strings verbatim: tooltips `'Search'`/`'Hide search'`/`'Filters'`/`'Hide filters'`/`'Clear tags'`/`'Clear'`; search field label `'Search'`; filter panel `'Templates'`, `'Tags'`, `'Tags (N)'`, `'Select'`, `'Exclude'`/`'Include'`/`'Only'`, `'Exclude templates'`/`'Include templates'`/`'Only templates'`; empty states `'No <plural> found'`, `'No <plural> match your filters.'`, `'Create <plural> in the Komodo web interface.'`, `'Clear filters'`, `'Filter by tag'`; error `'Failed to load <plural>'` with `'Retry'` (from `ErrorStateView`).
- Preserve these per-feature strings verbatim: titles `'Builds'`/`'Repos'`/`'Actions'`/`'Procedures'`/`'Syncs'`; tag-sheet `resourceName` `'builds'`/`'repos'`/`'actions'`/`'procedures'`/`'syncs'`; snackbars — builds & repos `'Action completed successfully'`, actions `'Action started'`, procedures `'Procedure started'`, syncs `'Sync started'`, all failures `'Action failed. Please try again.'`; skeleton placeholders — builds `'Build name'`/`'Repo • Commit • Builder'`/`'Queued'`/`'Duration 3m'`, repos `'Repo name'`/`'Provider - Branch - Server'`/`'Synced'`/`'Builds 12'`, actions `'Action name'`/`'Owner - Trigger - Resource'`/`'Idle'`/`'Last run 1h'`, procedures `'Procedure name'`/`'Owner - Last run - Duration'`/`'Idle'`/`'Steps 5'`, syncs `'Sync name'`/`'Repo - Server - Schedule'`/`'Idle'`/`'Last run 2m'`.
- Preserve exact filter semantics (now centralized): query is `trim().toLowerCase()`; selected tags are trimmed/lowercased with blanks dropped; template filter defaults to `TemplateFilter.exclude`; tag filter matches an item when ANY item tag (trimmed/lowercased) is in the selected set; search matches when ANY search field (`toLowerCase()`, NOT trimmed — matches original) contains the query OR any display tag (`trim().toLowerCase()`) contains it; display tags map ids via `tagNameById` with raw fallback, preserving item order; fallback tag options are collected from items (trimmed, deduped, sorted) only when the tags API returns none.
- Keep public view class names and file paths (`BuildsListView` in `lib/features/builds/presentation/views/builds_list_view.dart`, etc.) — `lib/core/router/app_router.dart` must NOT be modified.
- Lints: `very_good_analysis` via `analysis_options.yaml`; every task ends with `fvm flutter analyze` reporting `No issues found!`.
- One commit per task; run `fvm flutter test` (full suite) green before each commit; end commit messages with the `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` trailer.
- After any `@riverpod`/`@freezed` change (and after deleting provider files) run: `fvm dart run build_runner build --delete-conflicting-outputs`. Never edit or commit `*.g.dart`/`*.freezed.dart` (gitignored).
- OUT OF SCOPE (non-goals, future plan): deployments, stacks, servers, containers list views — they are a diverged second generation. Also out of scope: `test/widget/confirmations/` (a concurrent worker owns that directory — do not create, modify, or delete anything in it).

---

### Task 1: Shared Filtering Primitives (`ResourceKind` + pure filter functions)

**Files:**
- Create: `lib/shared/resources/models/resource_kind.dart`
- Create: `lib/shared/resources/resource_list_filtering.dart`
- Test: `test/unit/shared/resources/resource_list_filtering_test.dart`

**Interfaces:**
- Consumes: `TemplateFilter` enum from `lib/core/widgets/filters/template_filter.dart` (values: `exclude`, `include`, `only`).
- Produces:
  - `enum ResourceKind { builds, repos, actions, procedures, syncs }`
  - `List<T> applyResourceFilters<T>(List<T> items, {required String query, required Set<String> selectedTags, required TemplateFilter templateFilter, required Map<String, String> tagNameById, required bool Function(T item) isTemplate, required List<String> Function(T item) tagsOf, required List<String> Function(T item) searchFieldsOf})`
  - `bool hasActiveResourceFilters({required String query, required Set<String> selectedTags, required TemplateFilter templateFilter})`
  - `List<String> collectResourceTags<T>(List<T> items, List<String> Function(T item) tagsOf)`
  - `List<String> resourceDisplayTags(List<String> tags, Map<String, String> tagNameById)`

- [ ] **Step 1: Write the failing test**

Create `test/unit/shared/resources/resource_list_filtering_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/unit/shared/resources/resource_list_filtering_test.dart` / Expected: compilation failure — `Error: Error when reading 'lib/shared/resources/resource_list_filtering.dart': No such file or directory` (the library under test does not exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `lib/shared/resources/models/resource_kind.dart`:

```dart
/// Identity of a filterable resource list.
///
/// Used to key the shared filter-state providers so each resource screen
/// gets independent search/tag/template state.
enum ResourceKind { builds, repos, actions, procedures, syncs }
```

Create `lib/shared/resources/resource_list_filtering.dart`. The bodies are extracted verbatim from the per-feature `_applyFilters` / `_hasActiveFilters` / `_collectTags` / `_displayTags` functions (e.g. `lib/features/builds/presentation/views/builds_list_view.dart:657-730`), with the item-specific reads replaced by extractor callbacks:

```dart
import 'package:komodo_go/core/widgets/filters/template_filter.dart';

/// Applies template, tag, and search filters to a resource list.
///
/// Extracted from the identical per-feature `_applyFilters` functions in the
/// builds/repos/actions/procedures/syncs list views; semantics must not
/// change. See the plan's Global Constraints for the exact rules.
List<T> applyResourceFilters<T>(
  List<T> items, {
  required String query,
  required Set<String> selectedTags,
  required TemplateFilter templateFilter,
  required Map<String, String> tagNameById,
  required bool Function(T item) isTemplate,
  required List<String> Function(T item) tagsOf,
  required List<String> Function(T item) searchFieldsOf,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final normalizedTags = selectedTags
      .map((tag) => tag.trim().toLowerCase())
      .where((tag) => tag.isNotEmpty)
      .toSet();

  return items.where((item) {
    switch (templateFilter) {
      case TemplateFilter.exclude:
        if (isTemplate(item)) return false;
      case TemplateFilter.only:
        if (!isTemplate(item)) return false;
      case TemplateFilter.include:
        break;
    }

    if (normalizedTags.isNotEmpty) {
      final tagMatches = tagsOf(item).any(
        (tag) => normalizedTags.contains(tag.trim().toLowerCase()),
      );
      if (!tagMatches) return false;
    }

    if (normalizedQuery.isEmpty) return true;

    final fieldMatch = searchFieldsOf(item).any(
      (field) => field.toLowerCase().contains(normalizedQuery),
    );
    final displayTags = resourceDisplayTags(tagsOf(item), tagNameById);
    final tagMatch = displayTags.any(
      (tag) => tag.trim().toLowerCase().contains(normalizedQuery),
    );

    return fieldMatch || tagMatch;
  }).toList();
}

/// True when any filter deviates from its default
/// (non-blank query, selected tags, or a non-`exclude` template mode).
bool hasActiveResourceFilters({
  required String query,
  required Set<String> selectedTags,
  required TemplateFilter templateFilter,
}) {
  return query.trim().isNotEmpty ||
      selectedTags.isNotEmpty ||
      templateFilter != TemplateFilter.exclude;
}

/// Collects the distinct, trimmed, sorted tag values across [items].
///
/// Used as fallback tag options when the tags API returns nothing.
List<String> collectResourceTags<T>(
  List<T> items,
  List<String> Function(T item) tagsOf,
) {
  final tags = <String>{};
  for (final item in items) {
    for (final tag in tagsOf(item)) {
      if (tag.trim().isNotEmpty) {
        tags.add(tag.trim());
      }
    }
  }
  final sorted = tags.toList()..sort();
  return sorted;
}

/// Maps raw tag ids to display names via [tagNameById], falling back to the
/// raw value, preserving item order.
List<String> resourceDisplayTags(
  List<String> tags,
  Map<String, String> tagNameById,
) {
  if (tags.isEmpty) return const [];
  return [
    for (final tag in tags) tagNameById[tag] ?? tag,
  ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/unit/shared/resources/resource_list_filtering_test.dart` / Expected: `All tests passed!`. Then run `fvm flutter analyze` / Expected: `No issues found!`. Then run the full suite `fvm flutter test` / Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/resources/models/resource_kind.dart lib/shared/resources/resource_list_filtering.dart test/unit/shared/resources/resource_list_filtering_test.dart
git commit -m "refactor: add shared resource list filtering primitives

Pure, unit-tested extraction of the filter logic duplicated across the
builds/repos/actions/procedures/syncs list views.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Shared Resource Filter Providers (Riverpod family keyed by `ResourceKind`)

**Files:**
- Create: `lib/shared/resources/providers/resource_filters_provider.dart` (generates `resource_filters_provider.g.dart`)
- Test: `test/unit/shared/resources/resource_filters_provider_test.dart`

**Interfaces:**
- Consumes: `ResourceKind` from Task 1 (`lib/shared/resources/models/resource_kind.dart`); `TemplateFilter` from `lib/core/widgets/filters/template_filter.dart`.
- Produces (all autoDispose family providers, mirroring the API of the five deleted-later `<f>_filters_provider.dart` files exactly):
  - `resourceSearchQueryProvider(ResourceKind kind)` → `String`; notifier `ResourceSearchQuery` with `String get query` / `set query(String value)`.
  - `resourceTagFilterProvider(ResourceKind kind)` → `Set<String>`; notifier `ResourceTagFilter` with `Set<String> get selected` / `set selected(Set<String> value)` / `void toggle(String tag)` / `void clear()`.
  - `resourceTemplateFilterStateProvider(ResourceKind kind)` → `TemplateFilter`; notifier `ResourceTemplateFilterState` with `TemplateFilter get value` / `set value(TemplateFilter next)`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/shared/resources/resource_filters_provider_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/unit/shared/resources/resource_filters_provider_test.dart` / Expected: compilation failure — `Error: Error when reading 'lib/shared/resources/providers/resource_filters_provider.dart': No such file or directory`.

- [ ] **Step 3: Write minimal implementation**

Create `lib/shared/resources/providers/resource_filters_provider.dart`. Notifier bodies are copied verbatim from `lib/features/builds/presentation/providers/builds_filters_provider.dart` (which is byte-identical modulo rename to the repos/actions/procedures/syncs versions), converted to a family over `ResourceKind`:

```dart
import 'package:komodo_go/core/widgets/filters/template_filter.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'resource_filters_provider.g.dart';

/// Search query for a resource list, keyed by [ResourceKind].
@riverpod
class ResourceSearchQuery extends _$ResourceSearchQuery {
  @override
  String build(ResourceKind kind) => '';

  String get query => state;

  set query(String value) => state = value;
}

/// Selected tag filter for a resource list, keyed by [ResourceKind].
@riverpod
class ResourceTagFilter extends _$ResourceTagFilter {
  @override
  Set<String> build(ResourceKind kind) => <String>{};

  Set<String> get selected => state;

  set selected(Set<String> value) => state = Set<String>.from(value);

  void toggle(String tag) {
    final next = Set<String>.from(state);
    if (next.contains(tag)) {
      next.remove(tag);
    } else {
      next.add(tag);
    }
    state = next;
  }

  void clear() => state = <String>{};
}

/// Template filter mode for a resource list, keyed by [ResourceKind].
@riverpod
class ResourceTemplateFilterState extends _$ResourceTemplateFilterState {
  @override
  TemplateFilter build(ResourceKind kind) => TemplateFilter.exclude;

  TemplateFilter get value => state;

  set value(TemplateFilter next) => state = next;
}
```

Then run code generation:

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/unit/shared/resources/resource_filters_provider_test.dart` / Expected: `All tests passed!`. Then `fvm flutter analyze` / Expected: `No issues found!`. Then `fvm flutter test` / Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/resources/providers/resource_filters_provider.dart test/unit/shared/resources/resource_filters_provider_test.dart
git commit -m "refactor: add shared resource filter providers keyed by ResourceKind

One Riverpod family per filter type replaces five identical
<feature>_filters_provider.dart files (deleted per feature during
migration). AutoDispose-per-key preserves the reset-on-leave lifecycle.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 3: `ResourceListConfig<T>` + Generic `ResourceListView<T>` Scaffold

**Files:**
- Create: `lib/shared/resources/models/resource_list_config.dart`
- Create: `lib/core/widgets/resource_list/resource_list_view.dart`
- Test: `test/widget/resource_list_view_test.dart`

**Interfaces:**
- Consumes (from Task 1): `ResourceKind`; `applyResourceFilters<T>`, `hasActiveResourceFilters`, `collectResourceTags<T>`, `resourceDisplayTags` from `package:komodo_go/shared/resources/resource_list_filtering.dart`.
- Consumes (from Task 2): `resourceSearchQueryProvider(kind)`, `resourceTagFilterProvider(kind)`, `resourceTemplateFilterStateProvider(kind)`.
- Consumes (existing): `MainAppBar`, `ErrorStateView`, `TagFilterSheet`/`TagOption`, `TemplateFilter`, `AppSkeletonCard`, `AppCardSurface`, `AppMotion`/`AppFadeSlide`, `AppIcons`, `TextPill`/`ValuePill` (detail_pills), `tagsProvider`, `Skeletonizer`.
- Produces:
  - `class ResourceListConfig<T>` with constructor `ResourceListConfig({required ResourceKind kind, required String title, required String resourceName, required IconData icon, required Color markColor, required Key searchFieldKey, required String skeletonTitle, required String skeletonSubtitle, required String skeletonChipLeft, required String skeletonChipRight, required AsyncValue<List<T>> Function(WidgetRef ref) watchList, required Future<void> Function(WidgetRef ref) refreshList, required void Function(WidgetRef ref) invalidateList, required AsyncValue<void> Function(WidgetRef ref) watchActionsState, required bool Function(T item) isTemplate, required List<String> Function(T item) tagsOf, required List<String> Function(T item) searchFieldsOf, required Widget Function(BuildContext context, WidgetRef ref, T item, List<String> displayTags) cardBuilder})`
  - `class ResourceListView<T> extends ConsumerStatefulWidget` with constructor `ResourceListView({required ResourceListConfig<T> config, Key? key})`

- [ ] **Step 1: Write the failing test**

Create `test/widget/resource_list_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

class _FakeItem {
  const _FakeItem({
    required this.id,
    required this.name,
    this.template = false,
    this.tags = const [],
  });

  final String id;
  final String name;
  final bool template;
  final List<String> tags;
}

ResourceListConfig<_FakeItem> _config({
  required AsyncValue<List<_FakeItem>> Function(WidgetRef ref) watchList,
  void Function(WidgetRef ref)? invalidateList,
}) {
  return ResourceListConfig<_FakeItem>(
    kind: ResourceKind.builds,
    title: 'Fakes',
    resourceName: 'fakes',
    icon: Icons.widgets,
    markColor: Colors.teal,
    searchFieldKey: const ValueKey('fakes_search'),
    skeletonTitle: 'Fake name',
    skeletonSubtitle: 'Fake subtitle',
    skeletonChipLeft: 'Idle',
    skeletonChipRight: 'Last run 1h',
    watchList: watchList,
    refreshList: (ref) async {},
    invalidateList: invalidateList ?? (ref) {},
    watchActionsState: (ref) => const AsyncValue.data(null),
    isTemplate: (item) => item.template,
    tagsOf: (item) => item.tags,
    searchFieldsOf: (item) => [item.name],
    cardBuilder: (context, ref, item, displayTags) => Card(
      key: ValueKey('fake_card_${item.id}'),
      child: ListTile(
        title: Text(item.name),
        subtitle: Text(displayTags.join(',')),
      ),
    ),
  );
}

Widget _app(ResourceListConfig<_FakeItem> config) {
  return ProviderScope(
    overrides: [tagsProvider.overrideWith(() => _TestTags(const []))],
    child: MaterialApp(home: ResourceListView<_FakeItem>(config: config)),
  );
}

void main() {
  const items = [
    _FakeItem(id: 'f1', name: 'Alpha One', tags: ['t1']),
    _FakeItem(id: 'f2', name: 'Beta Two'),
    _FakeItem(id: 'f3', name: 'Tmpl', template: true),
  ];

  testWidgets('renders title and cards; excludes templates by default',
      (tester) async {
    await tester.pumpWidget(
      _app(_config(watchList: (ref) => const AsyncValue.data(items))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fakes'), findsOneWidget);
    expect(find.byKey(const ValueKey('fake_card_f1')), findsOneWidget);
    expect(find.byKey(const ValueKey('fake_card_f2')), findsOneWidget);
    expect(find.byKey(const ValueKey('fake_card_f3')), findsNothing);
    // Display tags flow through to the card builder (raw fallback).
    expect(find.text('t1'), findsOneWidget);
  });

  testWidgets('search filters cards; Clear filters restores them',
      (tester) async {
    await tester.pumpWidget(
      _app(_config(watchList: (ref) => const AsyncValue.data(items))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('fakes_search')), 'beta');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fake_card_f2')), findsOneWidget);
    expect(find.byKey(const ValueKey('fake_card_f1')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('fakes_search')), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No fakes found'), findsOneWidget);
    expect(find.text('No fakes match your filters.'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fake_card_f1')), findsOneWidget);
    expect(find.byKey(const ValueKey('fake_card_f2')), findsOneWidget);
  });

  testWidgets('empty data without filters shows create-in-web copy',
      (tester) async {
    await tester.pumpWidget(
      _app(
        _config(
          watchList: (ref) => const AsyncValue.data(<_FakeItem>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No fakes found'), findsOneWidget);
    expect(
      find.text('Create fakes in the Komodo web interface.'),
      findsOneWidget,
    );
    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('error state shows retry and invokes invalidateList',
      (tester) async {
    var invalidated = false;
    await tester.pumpWidget(
      _app(
        _config(
          watchList: (ref) =>
              AsyncValue.error(Exception('boom'), StackTrace.empty),
          invalidateList: (ref) => invalidated = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load fakes'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(invalidated, isTrue);
  });

  testWidgets('loading state shows skeleton placeholders', (tester) async {
    await tester.pumpWidget(
      _app(_config(watchList: (ref) => const AsyncValue.loading())),
    );
    await tester.pump();

    expect(find.text('Fake name'), findsWidgets);
    expect(find.text('Fake subtitle'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/widget/resource_list_view_test.dart` / Expected: compilation failure — `Error: Error when reading 'lib/core/widgets/resource_list/resource_list_view.dart': No such file or directory` (and the same for `resource_list_config.dart`).

- [ ] **Step 3: Write minimal implementation**

Create `lib/shared/resources/models/resource_list_config.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';

/// Per-resource configuration consumed by `ResourceListView<T>`.
///
/// Everything that differed between the five copied list views
/// (builds/repos/actions/procedures/syncs) lives here; the shared view
/// renders identical chrome around it.
class ResourceListConfig<T> {
  const ResourceListConfig({
    required this.kind,
    required this.title,
    required this.resourceName,
    required this.icon,
    required this.markColor,
    required this.searchFieldKey,
    required this.skeletonTitle,
    required this.skeletonSubtitle,
    required this.skeletonChipLeft,
    required this.skeletonChipRight,
    required this.watchList,
    required this.refreshList,
    required this.invalidateList,
    required this.watchActionsState,
    required this.isTemplate,
    required this.tagsOf,
    required this.searchFieldsOf,
    required this.cardBuilder,
  });

  /// Keys the shared filter providers.
  final ResourceKind kind;

  /// App bar title, e.g. `'Builds'`.
  final String title;

  /// Lowercase plural used in user-facing copy, e.g. `'builds'`. Drives:
  /// `'No <resourceName> found'`, `'No <resourceName> match your filters.'`,
  /// `'Create <resourceName> in the Komodo web interface.'`,
  /// `'Failed to load <resourceName>'`, and the tag sheet's `resourceName`.
  final String resourceName;

  /// App bar and empty-state icon, e.g. `AppIcons.builds`.
  final IconData icon;

  /// App bar mark color, e.g. `AppTokens.resourceBuilds`.
  final Color markColor;

  /// Search `TextField` key, e.g. `ValueKey('builds_search')`.
  /// Must stay identical to the pre-refactor key.
  final Key searchFieldKey;

  /// Skeleton placeholder title, e.g. `'Build name'`.
  final String skeletonTitle;

  /// Skeleton placeholder subtitle, e.g. `'Repo • Commit • Builder'`.
  final String skeletonSubtitle;

  /// Left skeleton chip label, e.g. `'Queued'`.
  final String skeletonChipLeft;

  /// Right skeleton chip label, e.g. `'Duration 3m'`.
  final String skeletonChipRight;

  /// Watches the list provider,
  /// e.g. `(ref) => ref.watch(buildsProvider)`.
  final AsyncValue<List<T>> Function(WidgetRef ref) watchList;

  /// Pull-to-refresh target,
  /// e.g. `(ref) => ref.read(buildsProvider.notifier).refresh()`.
  final Future<void> Function(WidgetRef ref) refreshList;

  /// Error-state retry target, e.g. `(ref) => ref.invalidate(buildsProvider)`.
  final void Function(WidgetRef ref) invalidateList;

  /// Watches the actions notifier that drives the busy overlay,
  /// e.g. `(ref) => ref.watch(buildActionsProvider)`.
  final AsyncValue<void> Function(WidgetRef ref) watchActionsState;

  /// Whether the item is a template (drives [TemplateFilter] behavior).
  final bool Function(T item) isTemplate;

  /// Raw tag values of the item (ids or names, as returned by the API).
  final List<String> Function(T item) tagsOf;

  /// Search haystack for the item; must include the name plus any
  /// feature-specific fields the old view matched on.
  final List<String> Function(T item) searchFieldsOf;

  /// Builds the resource card, including onTap navigation and action
  /// handling (snackbars, action-provider calls).
  final Widget Function(
    BuildContext context,
    WidgetRef ref,
    T item,
    List<String> displayTags,
  ) cardBuilder;
}
```

Create `lib/core/widgets/resource_list/resource_list_view.dart`. This is the builds view (`lib/features/builds/presentation/views/builds_list_view.dart`, the canonical copy) with every per-feature literal replaced by `config.*` and the filter logic delegated to Task 1/2. The private widgets `_FilterRow` and `_FilterValueButton` are copied VERBATIM from `builds_list_view.dart` lines 416–448 and 450–494 respectively (do not reprint here; the source file still exists until Task 4). Everything else is printed in full:

```dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/filters/tag_filter_sheet.dart';
import 'package:komodo_go/core/widgets/filters/template_filter.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';
import 'package:komodo_go/shared/resources/providers/resource_filters_provider.dart';
import 'package:komodo_go/shared/resources/resource_list_filtering.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Generic list screen for Komodo resources
/// (builds, repos, actions, procedures, syncs).
///
/// All chrome — app bar, search, filters panel, tag sheet, skeletons,
/// empty and error states, pull-to-refresh, busy overlay — is shared;
/// everything resource-specific comes from [ResourceListConfig].
class ResourceListView<T> extends ConsumerStatefulWidget {
  const ResourceListView({required this.config, super.key});

  final ResourceListConfig<T> config;

  @override
  ConsumerState<ResourceListView<T>> createState() =>
      _ResourceListViewState<T>();
}

class _ResourceListViewState<T> extends ConsumerState<ResourceListView<T>> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  ProviderSubscription<String>? _searchQuerySubscription;
  bool _isSearchVisible = false;
  bool _isFiltersVisible = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(resourceSearchQueryProvider(widget.config.kind)),
    );
    _searchFocusNode = FocusNode();
    _searchQuerySubscription = ref.listenManual<String>(
      resourceSearchQueryProvider(widget.config.kind),
      (previous, next) {
        if (_searchController.text == next) return;
        final selection = _searchController.selection;
        _searchController.text = next;
        _searchController.selection = selection.copyWith(
          baseOffset: _searchController.text.length,
          extentOffset: _searchController.text.length,
        );
      },
    );
  }

  @override
  void dispose() {
    _searchQuerySubscription?.close();
    _searchQuerySubscription = null;
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final itemsAsync = config.watchList(ref);
    final actionsState = config.watchActionsState(ref);
    final tagsAsync = ref.watch(tagsProvider);
    final searchQuery = ref.watch(resourceSearchQueryProvider(config.kind));
    final selectedTags = ref.watch(resourceTagFilterProvider(config.kind));
    final templateFilter = ref.watch(
      resourceTemplateFilterStateProvider(config.kind),
    );

    final tagOptions = tagsAsync.maybeWhen(
      data: (tags) => [
        for (final tag in tags)
          if (tag.name.trim().isNotEmpty)
            TagOption(id: tag.id, name: tag.name.trim()),
      ],
      orElse: () => <TagOption>[],
    );
    final fallbackTags = itemsAsync.maybeWhen(
      data: (items) => collectResourceTags(items, config.tagsOf)
          .map((name) => TagOption(id: name, name: name))
          .toList(),
      orElse: () => <TagOption>[],
    );
    final availableTags = tagOptions.isNotEmpty ? tagOptions : fallbackTags;
    final tagNameById = {
      for (final tag in availableTags) tag.id: tag.name,
    };

    return Scaffold(
      appBar: MainAppBar(
        title: config.title,
        icon: config.icon,
        markColor: config.markColor,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _isSearchVisible ? 'Hide search' : 'Search',
            icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _isSearchVisible = !_isSearchVisible);
              if (_isSearchVisible) {
                Future<void>.delayed(const Duration(milliseconds: 50), () {
                  if (context.mounted) _searchFocusNode.requestFocus();
                });
              } else {
                FocusManager.instance.primaryFocus?.unfocus();
              }
            },
          ),
          IconButton(
            tooltip: _isFiltersVisible ? 'Hide filters' : 'Filters',
            icon: Icon(
              _isFiltersVisible ? Icons.tune : Icons.tune_outlined,
            ),
            onPressed: () => setState(() {
              _isFiltersVisible = !_isFiltersVisible;
            }),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => config.refreshList(ref),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.base,
                  switchInCurve: AppMotion.enterCurve,
                  switchOutCurve: AppMotion.exitCurve,
                  child: _isFiltersVisible
                      ? _FiltersPanel(
                          resourceName: config.resourceName,
                          templateFilter: templateFilter,
                          selectedTags: selectedTags,
                          availableTags: availableTags,
                          tagNameById: tagNameById,
                          onTemplateFilterChanged: (value) => ref
                              .read(
                                resourceTemplateFilterStateProvider(
                                  config.kind,
                                ).notifier,
                              )
                              .value = value,
                          onSelectTags: (value) => ref
                              .read(
                                resourceTagFilterProvider(config.kind).notifier,
                              )
                              .selected = value,
                          onClearTags: () => ref
                              .read(
                                resourceTagFilterProvider(config.kind).notifier,
                              )
                              .clear(),
                        )
                      : const SizedBox.shrink(),
                ),
                if (_isFiltersVisible) const Gap(12),
                AnimatedSwitcher(
                  duration: AppMotion.base,
                  switchInCurve: AppMotion.enterCurve,
                  switchOutCurve: AppMotion.exitCurve,
                  child: _isSearchVisible
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _SearchField(
                            fieldKey: config.searchFieldKey,
                            focusNode: _searchFocusNode,
                            controller: _searchController,
                            onChanged: (value) => ref
                                .read(
                                  resourceSearchQueryProvider(
                                    config.kind,
                                  ).notifier,
                                )
                                .query = value,
                            onClear: () {
                              _searchController.clear();
                              ref
                                  .read(
                                    resourceSearchQueryProvider(
                                      config.kind,
                                    ).notifier,
                                  )
                                  .query = '';
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const Gap(12),
                itemsAsync.when(
                  skipLoadingOnRefresh: true,
                  skipLoadingOnReload: true,
                  data: (items) {
                    final filtered = applyResourceFilters(
                      items,
                      query: searchQuery,
                      selectedTags: selectedTags,
                      templateFilter: templateFilter,
                      tagNameById: tagNameById,
                      isTemplate: config.isTemplate,
                      tagsOf: config.tagsOf,
                      searchFieldsOf: config.searchFieldsOf,
                    );
                    if (filtered.isEmpty) {
                      return _EmptyState(
                        icon: config.icon,
                        resourceName: config.resourceName,
                        hasFilters: hasActiveResourceFilters(
                          query: searchQuery,
                          selectedTags: selectedTags,
                          templateFilter: templateFilter,
                        ),
                        onClearFilters: () {
                          _searchController.clear();
                          ref
                              .read(
                                resourceSearchQueryProvider(
                                  config.kind,
                                ).notifier,
                              )
                              .query = '';
                          ref
                              .read(
                                resourceTagFilterProvider(config.kind).notifier,
                              )
                              .clear();
                          ref
                              .read(
                                resourceTemplateFilterStateProvider(
                                  config.kind,
                                ).notifier,
                              )
                              .value = TemplateFilter.exclude;
                        },
                        tagOptions: availableTags,
                        onSelectTags: (value) => ref
                            .read(
                              resourceTagFilterProvider(config.kind).notifier,
                            )
                            .selected = value,
                      );
                    }

                    return Column(
                      children: [
                        for (var i = 0; i < filtered.length; i++) ...[
                          AppFadeSlide(
                            delay: AppMotion.stagger(i),
                            play: i < 10,
                            child: config.cardBuilder(
                              context,
                              ref,
                              filtered[i],
                              resourceDisplayTags(
                                config.tagsOf(filtered[i]),
                                tagNameById,
                              ),
                            ),
                          ),
                          const Gap(12),
                        ],
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                  loading: () => _ResourceSkeletonList(
                    title: config.skeletonTitle,
                    subtitle: config.skeletonSubtitle,
                    chipLeft: config.skeletonChipLeft,
                    chipRight: config.skeletonChipRight,
                  ),
                  error: (error, stack) => ErrorStateView(
                    title: 'Failed to load ${config.resourceName}',
                    message: error.toString(),
                    onRetry: () => config.invalidateList(ref),
                  ),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: Theme.of(context).colorScheme.scrim.withValues(alpha: .25),
              child: const Center(child: AppSkeletonCard()),
            ),
        ],
      ),
    );
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.resourceName,
    required this.templateFilter,
    required this.selectedTags,
    required this.availableTags,
    required this.tagNameById,
    required this.onTemplateFilterChanged,
    required this.onSelectTags,
    required this.onClearTags,
  });

  final String resourceName;
  final TemplateFilter templateFilter;
  final Set<String> selectedTags;
  final List<TagOption> availableTags;
  final Map<String, String> tagNameById;
  final ValueChanged<TemplateFilter> onTemplateFilterChanged;
  final ValueChanged<Set<String>> onSelectTags;
  final VoidCallback onClearTags;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tagLabel =
        selectedTags.isEmpty ? 'Tags' : 'Tags (${selectedTags.length})';
    final templateLabel = switch (templateFilter) {
      TemplateFilter.exclude => 'Exclude',
      TemplateFilter.include => 'Include',
      TemplateFilter.only => 'Only',
    };

    return AppCardSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterRow(
            icon: AppIcons.factory,
            label: 'Templates',
            trailing: PopupMenuButton<TemplateFilter>(
              onSelected: onTemplateFilterChanged,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: TemplateFilter.exclude,
                  child: Text('Exclude templates'),
                ),
                PopupMenuItem(
                  value: TemplateFilter.include,
                  child: Text('Include templates'),
                ),
                PopupMenuItem(
                  value: TemplateFilter.only,
                  child: Text('Only templates'),
                ),
              ],
              child: _FilterValueButton(
                label: templateLabel,
                icon: Icons.expand_more,
              ),
            ),
          ),
          Divider(
            height: 20,
            color: scheme.outlineVariant.withValues(alpha: .35),
          ),
          _FilterRow(
            icon: AppIcons.tag,
            label: tagLabel,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FilterValueButton(
                  label: 'Select',
                  icon: Icons.tune,
                  onPressed: () async {
                    final next = await TagFilterSheet.show(
                      context,
                      availableTags: availableTags,
                      selected: selectedTags,
                      resourceName: resourceName,
                    );
                    if (next != null) {
                      onSelectTags(next);
                    }
                  },
                ),
                if (selectedTags.isNotEmpty) ...[
                  const Gap(6),
                  IconButton(
                    tooltip: 'Clear tags',
                    icon: const Icon(AppIcons.close),
                    onPressed: onClearTags,
                  ),
                ],
              ],
            ),
          ),
          if (selectedTags.isNotEmpty) ...[
            const Gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildSelectedTagPills(selectedTags, tagNameById),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSelectedTagPills(
    Set<String> tags,
    Map<String, String> tagNameById,
  ) {
    final labels = [
      for (final tag in tags) tagNameById[tag] ?? tag,
    ]..sort();
    final capped = labels.take(6).toList();
    final remaining = labels.length - capped.length;
    return [
      for (final tag in capped) TextPill(label: tag),
      if (remaining > 0) ValuePill(label: 'More', value: '+$remaining'),
    ];
  }
}

// _FilterRow: copy VERBATIM from
// lib/features/builds/presentation/views/builds_list_view.dart lines 416-448.
// _FilterValueButton: copy VERBATIM from
// lib/features/builds/presentation/views/builds_list_view.dart lines 450-494.

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.fieldKey,
    required this.focusNode,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final Key fieldKey;
  final FocusNode focusNode;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      focusNode: focusNode,
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: 'Search',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: onClear,
              ),
      ),
    );
  }
}

class _ResourceSkeletonList extends StatelessWidget {
  const _ResourceSkeletonList({
    required this.title,
    required this.subtitle,
    required this.chipLeft,
    required this.chipRight,
  });

  final String title;
  final String subtitle;
  final String chipLeft;
  final String chipRight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, _) => const Gap(12),
        itemBuilder: (_, _) => AppCardSurface(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 16),
                    const Gap(10),
                    Expanded(
                      child: Text(title, style: textTheme.titleSmall),
                    ),
                    const Gap(8),
                    const CircleAvatar(radius: 6),
                  ],
                ),
                const Gap(10),
                Text(subtitle, style: textTheme.bodySmall),
                const Gap(10),
                Row(
                  children: [
                    Chip(label: Text(chipLeft)),
                    const Gap(8),
                    Chip(label: Text(chipRight)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.resourceName,
    required this.hasFilters,
    required this.onClearFilters,
    required this.tagOptions,
    required this.onSelectTags,
  });

  final IconData icon;
  final String resourceName;
  final bool hasFilters;
  final VoidCallback onClearFilters;
  final List<TagOption> tagOptions;
  final ValueChanged<Set<String>> onSelectTags;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final message = hasFilters
        ? 'No $resourceName match your filters.'
        : 'Create $resourceName in the Komodo web interface.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: scheme.primary.withValues(alpha: 0.5),
            ),
            const Gap(16),
            Text('No $resourceName found', style: textTheme.titleMedium),
            const Gap(8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (hasFilters) ...[
              const Gap(16),
              FilledButton(
                onPressed: onClearFilters,
                child: const Text('Clear filters'),
              ),
            ],
            if (!hasFilters && tagOptions.isNotEmpty) ...[
              const Gap(16),
              OutlinedButton.icon(
                icon: const Icon(AppIcons.tag),
                label: const Text('Filter by tag'),
                onPressed: () async {
                  final next = await TagFilterSheet.show(
                    context,
                    availableTags: tagOptions,
                    selected: const <String>{},
                    resourceName: resourceName,
                  );
                  if (next != null) {
                    onSelectTags(next);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/widget/resource_list_view_test.dart` / Expected: `All tests passed!` (5 tests). Then `fvm flutter analyze` / Expected: `No issues found!`. Then `fvm flutter test` / Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/resources/models/resource_list_config.dart lib/core/widgets/resource_list/resource_list_view.dart test/widget/resource_list_view_test.dart
git commit -m "refactor: add generic ResourceListView scaffold + config model

Shared chrome for resource list screens; per-resource behavior is
injected via ResourceListConfig. Skeleton lists are normalized to
shrinkWrap + NeverScrollableScrollPhysics (fixes latent unbounded
height error in four of the five original skeletons).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 4: Migrate Builds (proving ground)

**Files:**
- Modify: `lib/features/builds/presentation/views/builds_list_view.dart` (replace the entire 730-line file with the ~75-line config below)
- Delete: `lib/features/builds/presentation/providers/builds_filters_provider.dart` (and its generated `builds_filters_provider.g.dart` from disk)
- Test: `test/widget/builds_view_test.dart` (new)

**Interfaces:**
- Consumes (from Task 3): `ResourceListView<T>({required ResourceListConfig<T> config})`; `ResourceListConfig<T>` constructor as specified in Task 3.
- Consumes (from Task 1): `ResourceKind.builds`.
- Consumes (existing, unchanged): `buildsProvider` / `Builds.refresh()`, `buildActionsProvider` / `BuildActions.run(String)` / `BuildActions.cancel(String)` from `builds_provider.dart`; `BuildCard` + `enum BuildAction { run, cancel }` from `build_card.dart`; `BuildListItem` (fields `id`, `name`, `template`, `tags`); `AppRoutes.builds`; `AppIcons.builds`; `AppTokens.resourceBuilds`; `AppSnackBar`.
- Produces: `BuildsListView` (same public class, same file path — router untouched).

- [ ] **Step 1: Write the failing test**

Create `test/widget/builds_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/builds/presentation/views/builds_list_view.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestBuilds extends Builds {
  _TestBuilds(this._builds);

  final List<BuildListItem> _builds;

  @override
  Future<List<BuildListItem>> build() async => _builds;
}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

Widget _app(List<BuildListItem> builds) {
  return ProviderScope(
    overrides: [
      buildsProvider.overrideWith(() => _TestBuilds(builds)),
      tagsProvider.overrideWith(() => _TestTags(const [])),
    ],
    child: const MaterialApp(home: BuildsListView()),
  );
}

void main() {
  final builds = [
    BuildListItem.fromJson(<String, dynamic>{
      'id': 'b1',
      'name': 'Build One',
      'info': <String, dynamic>{},
    }),
    BuildListItem.fromJson(<String, dynamic>{
      'id': 'b2',
      'name': 'Api Image',
      'info': <String, dynamic>{},
    }),
  ];

  testWidgets('Builds list renders build cards via ResourceListView',
      (tester) async {
    await tester.pumpWidget(_app(builds));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceListView<BuildListItem>), findsOneWidget);
    expect(find.text('Builds'), findsOneWidget);
    expect(find.byKey(const ValueKey('build_card_b1')), findsOneWidget);
    expect(find.byKey(const ValueKey('build_card_b2')), findsOneWidget);
  });

  testWidgets('search narrows builds by name via builds_search field',
      (tester) async {
    await tester.pumpWidget(_app(builds));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('builds_search')), 'api');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('build_card_b2')), findsOneWidget);
    expect(find.byKey(const ValueKey('build_card_b1')), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/widget/builds_view_test.dart` / Expected: first test FAILS on `find.byType(ResourceListView<BuildListItem>)` with `Expected: exactly one matching candidate ... Actual: _TypeWidgetFinder:<Found 0 widgets with type "ResourceListView<BuildListItem>">` (the old hand-rolled view is still in place; the search test passes because behavior already exists).

- [ ] **Step 3: Write minimal implementation**

Replace the ENTIRE content of `lib/features/builds/presentation/views/builds_list_view.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/builds/presentation/widgets/build_card.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

/// View displaying the list of all builds.
class BuildsListView extends StatelessWidget {
  const BuildsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResourceListView<BuildListItem>(config: _buildsListConfig);
  }
}

final _buildsListConfig = ResourceListConfig<BuildListItem>(
  kind: ResourceKind.builds,
  title: 'Builds',
  resourceName: 'builds',
  icon: AppIcons.builds,
  markColor: AppTokens.resourceBuilds,
  searchFieldKey: const ValueKey('builds_search'),
  skeletonTitle: 'Build name',
  skeletonSubtitle: 'Repo • Commit • Builder',
  skeletonChipLeft: 'Queued',
  skeletonChipRight: 'Duration 3m',
  watchList: (ref) => ref.watch(buildsProvider),
  refreshList: (ref) => ref.read(buildsProvider.notifier).refresh(),
  invalidateList: (ref) => ref.invalidate(buildsProvider),
  watchActionsState: (ref) => ref.watch(buildActionsProvider),
  isTemplate: (item) => item.template,
  tagsOf: (item) => item.tags,
  searchFieldsOf: (item) => [item.name],
  cardBuilder: (context, ref, item, displayTags) => BuildCard(
    buildItem: item,
    displayTags: displayTags,
    onTap: () => context.push(
      '${AppRoutes.builds}/${item.id}?name=${Uri.encodeComponent(item.name)}',
    ),
    onAction: (action) => _handleAction(context, ref, item.id, action),
  ),
);

Future<void> _handleAction(
  BuildContext context,
  WidgetRef ref,
  String buildId,
  BuildAction action,
) async {
  final actions = ref.read(buildActionsProvider.notifier);
  final success = await switch (action) {
    BuildAction.run => actions.run(buildId),
    BuildAction.cancel => actions.cancel(buildId),
  };

  if (context.mounted) {
    AppSnackBar.show(
      context,
      success
          ? 'Action completed successfully'
          : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}
```

Then delete the now-dead per-feature filter state (its only consumer was the old view):

```bash
rm lib/features/builds/presentation/providers/builds_filters_provider.dart
rm -f lib/features/builds/presentation/providers/builds_filters_provider.g.dart
fvm dart run build_runner build --delete-conflicting-outputs
```

Verify nothing references the deleted providers: `grep -rn "buildsSearchQueryProvider\|buildsTagFilterProvider\|buildsTemplateFilterStateProvider\|builds_filters_provider" lib test integration_test` must return no matches.

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/widget/builds_view_test.dart` / Expected: `All tests passed!` (2 tests). Then `fvm flutter analyze` / Expected: `No issues found!`. Then `fvm flutter test` / Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/builds/presentation/views/builds_list_view.dart test/widget/builds_view_test.dart
git rm lib/features/builds/presentation/providers/builds_filters_provider.dart
git commit -m "refactor: migrate builds list to shared ResourceListView

730-line hand-rolled view becomes a ~75-line config; per-feature filter
providers deleted in favor of the shared ResourceKind-keyed family.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Migrate Repos

**Files:**
- Modify: `lib/features/repos/presentation/views/repos_list_view.dart` (replace the entire 738-line file with the config below)
- Delete: `lib/features/repos/presentation/providers/repos_filters_provider.dart` (and its generated `repos_filters_provider.g.dart` from disk)
- Test: `test/widget/repos_view_test.dart` (new)

**Interfaces:**
- Consumes (from Task 3): `ResourceListView<T>({required ResourceListConfig<T> config})` from `package:komodo_go/core/widgets/resource_list/resource_list_view.dart`; `ResourceListConfig<T>` from `package:komodo_go/shared/resources/models/resource_list_config.dart`.
- Consumes (from Task 1): `ResourceKind.repos` from `package:komodo_go/shared/resources/models/resource_kind.dart`.
- Consumes (existing, unchanged): `reposProvider` / `Repos.refresh()`, `repoActionsProvider` / `RepoActions.clone(String)` / `RepoActions.pull(String)` / `RepoActions.buildRepo(String)` from `repos_provider.dart`; `RepoCard` + `enum RepoAction { clone, pull, build }` from `repo_card.dart`; `RepoListItem` (fields `id`, `name`, `template`, `tags`, `info.repo`, `info.branch`, `info.gitProvider`, `info.repoLink`, `info.state.displayName`); `AppRoutes.repos`; `AppIcons.repos`; `AppTokens.resourceRepos`; `AppSnackBar`.
- Produces: `ReposListView` (same public class, same file path — router untouched).

- [ ] **Step 1: Write the failing test**

Create `test/widget/repos_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/repos/presentation/views/repos_list_view.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestRepos extends Repos {
  _TestRepos(this._repos);

  final List<RepoListItem> _repos;

  @override
  Future<List<RepoListItem>> build() async => _repos;
}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

Widget _app(List<RepoListItem> repos) {
  return ProviderScope(
    overrides: [
      reposProvider.overrideWith(() => _TestRepos(repos)),
      tagsProvider.overrideWith(() => _TestTags(const [])),
    ],
    child: const MaterialApp(home: ReposListView()),
  );
}

void main() {
  final repos = [
    RepoListItem.fromJson(<String, dynamic>{
      'id': 'r1',
      'name': 'Repo One',
      'info': <String, dynamic>{},
    }),
    RepoListItem.fromJson(<String, dynamic>{
      'id': 'r2',
      'name': 'Infra Config',
      'info': <String, dynamic>{'branch': 'develop'},
    }),
  ];

  testWidgets('Repos list renders repo cards via ResourceListView',
      (tester) async {
    await tester.pumpWidget(_app(repos));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceListView<RepoListItem>), findsOneWidget);
    expect(find.text('Repos'), findsOneWidget);
    expect(find.byKey(const ValueKey('repo_card_r1')), findsOneWidget);
    expect(find.byKey(const ValueKey('repo_card_r2')), findsOneWidget);
  });

  testWidgets('search matches repo info fields (branch) via repos_search',
      (tester) async {
    await tester.pumpWidget(_app(repos));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('repos_search')),
      'develop',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('repo_card_r2')), findsOneWidget);
    expect(find.byKey(const ValueKey('repo_card_r1')), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/widget/repos_view_test.dart` / Expected: first test FAILS on `find.byType(ResourceListView<RepoListItem>)` with `Found 0 widgets with type "ResourceListView<RepoListItem>"`.

- [ ] **Step 3: Write minimal implementation**

Replace the ENTIRE content of `lib/features/repos/presentation/views/repos_list_view.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/repos/presentation/widgets/repo_card.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

/// View displaying the list of all repos.
class ReposListView extends StatelessWidget {
  const ReposListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResourceListView<RepoListItem>(config: _reposListConfig);
  }
}

final _reposListConfig = ResourceListConfig<RepoListItem>(
  kind: ResourceKind.repos,
  title: 'Repos',
  resourceName: 'repos',
  icon: AppIcons.repos,
  markColor: AppTokens.resourceRepos,
  searchFieldKey: const ValueKey('repos_search'),
  skeletonTitle: 'Repo name',
  skeletonSubtitle: 'Provider - Branch - Server',
  skeletonChipLeft: 'Synced',
  skeletonChipRight: 'Builds 12',
  watchList: (ref) => ref.watch(reposProvider),
  refreshList: (ref) => ref.read(reposProvider.notifier).refresh(),
  invalidateList: (ref) => ref.invalidate(reposProvider),
  watchActionsState: (ref) => ref.watch(repoActionsProvider),
  isTemplate: (item) => item.template,
  tagsOf: (item) => item.tags,
  searchFieldsOf: (item) => [
    item.name,
    item.info.repo,
    item.info.branch,
    item.info.gitProvider,
    item.info.repoLink,
    item.info.state.displayName,
  ],
  cardBuilder: (context, ref, item, displayTags) => RepoCard(
    repo: item,
    displayTags: displayTags,
    onTap: () => context.push(
      '${AppRoutes.repos}/${item.id}?name=${Uri.encodeComponent(item.name)}',
    ),
    onAction: (action) => _handleAction(context, ref, item.id, action),
  ),
);

Future<void> _handleAction(
  BuildContext context,
  WidgetRef ref,
  String repoId,
  RepoAction action,
) async {
  final actions = ref.read(repoActionsProvider.notifier);
  final success = await switch (action) {
    RepoAction.clone => actions.clone(repoId),
    RepoAction.pull => actions.pull(repoId),
    RepoAction.build => actions.buildRepo(repoId),
  };

  if (context.mounted) {
    AppSnackBar.show(
      context,
      success
          ? 'Action completed successfully'
          : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}
```

Then delete the dead filter providers and regenerate:

```bash
rm lib/features/repos/presentation/providers/repos_filters_provider.dart
rm -f lib/features/repos/presentation/providers/repos_filters_provider.g.dart
fvm dart run build_runner build --delete-conflicting-outputs
```

Verify: `grep -rn "reposSearchQueryProvider\|reposTagFilterProvider\|reposTemplateFilterStateProvider\|repos_filters_provider" lib test integration_test` must return no matches.

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/widget/repos_view_test.dart` / Expected: `All tests passed!` (2 tests). Then `fvm flutter analyze` / Expected: `No issues found!`. Then `fvm flutter test` / Expected: all green (including the pre-existing `test/widget/stacks_view_test.dart`, which overrides `reposProvider` — unchanged by this task).

- [ ] **Step 5: Commit**

```bash
git add lib/features/repos/presentation/views/repos_list_view.dart test/widget/repos_view_test.dart
git rm lib/features/repos/presentation/providers/repos_filters_provider.dart
git commit -m "refactor: migrate repos list to shared ResourceListView

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 6: Migrate Actions

**Files:**
- Modify: `lib/features/actions/presentation/views/actions_list_view.dart` (replace the entire 725-line file with the config below)
- Delete: `lib/features/actions/presentation/providers/actions_filters_provider.dart` (and its generated `actions_filters_provider.g.dart` from disk)
- Test: `test/widget/actions_view_test.dart` (new)

**Interfaces:**
- Consumes (from Task 3): `ResourceListView<T>({required ResourceListConfig<T> config})` from `package:komodo_go/core/widgets/resource_list/resource_list_view.dart`; `ResourceListConfig<T>` from `package:komodo_go/shared/resources/models/resource_list_config.dart`.
- Consumes (from Task 1): `ResourceKind.actions` from `package:komodo_go/shared/resources/models/resource_kind.dart`.
- Consumes (existing, unchanged): `actionsProvider` / `Actions.refresh()`, `actionActionsProvider` / `ActionActions.run(String)` from `actions_provider.dart`; `ActionCard` (params `action`, `displayTags`, `onTap`, `onRun`) from `action_card.dart`; `ActionListItem` (fields `id`, `name`, `template`, `tags`, `info.state.name`); `AppRoutes.actions`; `AppIcons.actions`; `AppTokens.resourceActions`; `AppSnackBar`.
- Produces: `ActionsListView` (same public class, same file path — router untouched).

- [ ] **Step 1: Write the failing test**

Create `test/widget/actions_view_test.dart` (note: the material import hides Flutter's `Actions` widget so the `Actions` notifier from `actions_provider.dart` resolves unambiguously):

```dart
import 'package:flutter/material.dart' hide Actions;
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/actions/presentation/views/actions_list_view.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestActions extends Actions {
  _TestActions(this._actions);

  final List<ActionListItem> _actions;

  @override
  Future<List<ActionListItem>> build() async => _actions;
}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

Widget _app(List<ActionListItem> actions) {
  return ProviderScope(
    overrides: [
      actionsProvider.overrideWith(() => _TestActions(actions)),
      tagsProvider.overrideWith(() => _TestTags(const [])),
    ],
    child: const MaterialApp(home: ActionsListView()),
  );
}

void main() {
  final actions = [
    ActionListItem.fromJson(<String, dynamic>{
      'id': 'a1',
      'name': 'Action One',
      'info': <String, dynamic>{},
    }),
    ActionListItem.fromJson(<String, dynamic>{
      'id': 'a2',
      'name': 'Cleanup Job',
      'info': <String, dynamic>{},
    }),
  ];

  testWidgets('Actions list renders action cards via ResourceListView',
      (tester) async {
    await tester.pumpWidget(_app(actions));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceListView<ActionListItem>), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);
    expect(find.byKey(const ValueKey('action_card_a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('action_card_a2')), findsOneWidget);
  });

  testWidgets('search narrows actions by name via actions_search field',
      (tester) async {
    await tester.pumpWidget(_app(actions));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('actions_search')),
      'cleanup',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('action_card_a2')), findsOneWidget);
    expect(find.byKey(const ValueKey('action_card_a1')), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/widget/actions_view_test.dart` / Expected: first test FAILS on `find.byType(ResourceListView<ActionListItem>)` with `Found 0 widgets with type "ResourceListView<ActionListItem>"`.

- [ ] **Step 3: Write minimal implementation**

Replace the ENTIRE content of `lib/features/actions/presentation/views/actions_list_view.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/actions/presentation/widgets/action_card.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

/// View displaying the list of all actions.
class ActionsListView extends StatelessWidget {
  const ActionsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResourceListView<ActionListItem>(config: _actionsListConfig);
  }
}

final _actionsListConfig = ResourceListConfig<ActionListItem>(
  kind: ResourceKind.actions,
  title: 'Actions',
  resourceName: 'actions',
  icon: AppIcons.actions,
  markColor: AppTokens.resourceActions,
  searchFieldKey: const ValueKey('actions_search'),
  skeletonTitle: 'Action name',
  skeletonSubtitle: 'Owner - Trigger - Resource',
  skeletonChipLeft: 'Idle',
  skeletonChipRight: 'Last run 1h',
  watchList: (ref) => ref.watch(actionsProvider),
  refreshList: (ref) => ref.read(actionsProvider.notifier).refresh(),
  invalidateList: (ref) => ref.invalidate(actionsProvider),
  watchActionsState: (ref) => ref.watch(actionActionsProvider),
  isTemplate: (item) => item.template,
  tagsOf: (item) => item.tags,
  searchFieldsOf: (item) => [
    item.name,
    item.info.state.name,
  ],
  cardBuilder: (context, ref, item, displayTags) => ActionCard(
    action: item,
    displayTags: displayTags,
    onTap: () => context.push(
      '${AppRoutes.actions}/${item.id}?name=${Uri.encodeComponent(item.name)}',
    ),
    onRun: () => _runAction(context, ref, item.id),
  ),
);

Future<void> _runAction(
  BuildContext context,
  WidgetRef ref,
  String actionId,
) async {
  final actions = ref.read(actionActionsProvider.notifier);
  final success = await actions.run(actionId);

  if (context.mounted) {
    AppSnackBar.show(
      context,
      success ? 'Action started' : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}
```

Then delete the dead filter providers and regenerate:

```bash
rm lib/features/actions/presentation/providers/actions_filters_provider.dart
rm -f lib/features/actions/presentation/providers/actions_filters_provider.g.dart
fvm dart run build_runner build --delete-conflicting-outputs
```

Verify: `grep -rn "actionsSearchQueryProvider\|actionsTagFilterProvider\|actionsTemplateFilterStateProvider\|actions_filters_provider" lib test integration_test` must return no matches.

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/widget/actions_view_test.dart` / Expected: `All tests passed!` (2 tests). Then `fvm flutter analyze` / Expected: `No issues found!`. Then `fvm flutter test` / Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/actions/presentation/views/actions_list_view.dart test/widget/actions_view_test.dart
git rm lib/features/actions/presentation/providers/actions_filters_provider.dart
git commit -m "refactor: migrate actions list to shared ResourceListView

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Migrate Procedures

**Files:**
- Modify: `lib/features/procedures/presentation/views/procedures_list_view.dart` (replace the entire 739-line file with the config below)
- Delete: `lib/features/procedures/presentation/providers/procedures_filters_provider.dart` (and its generated `procedures_filters_provider.g.dart` from disk)
- Test: `test/widget/procedures_view_test.dart` (new)

**Interfaces:**
- Consumes (from Task 3): `ResourceListView<T>({required ResourceListConfig<T> config})` from `package:komodo_go/core/widgets/resource_list/resource_list_view.dart`; `ResourceListConfig<T>` from `package:komodo_go/shared/resources/models/resource_list_config.dart`.
- Consumes (from Task 1): `ResourceKind.procedures` from `package:komodo_go/shared/resources/models/resource_kind.dart`.
- Consumes (existing, unchanged): `proceduresProvider` / `Procedures.refresh()`, `procedureActionsProvider` / `ProcedureActions.run(String)` from `procedures_provider.dart`; `ProcedureCard` (params `procedure`, `displayTags`, `onTap`, `onRun`) from `procedure_card.dart`; `ProcedureListItem` (fields `id`, `name`, `template`, `tags`, `info.state.name`, `info.stages` — an `int`); `AppRoutes.procedures`; `AppIcons.procedures`; `AppTokens.resourceProcedures`; `AppSnackBar`.
- Produces: `ProceduresListView` (same public class, same file path — router untouched).

- [ ] **Step 1: Write the failing test**

Create `test/widget/procedures_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/procedures/presentation/views/procedures_list_view.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestProcedures extends Procedures {
  _TestProcedures(this._procedures);

  final List<ProcedureListItem> _procedures;

  @override
  Future<List<ProcedureListItem>> build() async => _procedures;
}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

Widget _app(List<ProcedureListItem> procedures) {
  return ProviderScope(
    overrides: [
      proceduresProvider.overrideWith(() => _TestProcedures(procedures)),
      tagsProvider.overrideWith(() => _TestTags(const [])),
    ],
    child: const MaterialApp(home: ProceduresListView()),
  );
}

void main() {
  final procedures = [
    ProcedureListItem.fromJson(<String, dynamic>{
      'id': 'p1',
      'name': 'Procedure One',
      'info': <String, dynamic>{},
    }),
    ProcedureListItem.fromJson(<String, dynamic>{
      'id': 'p2',
      'name': 'Nightly Backup',
      'info': <String, dynamic>{},
    }),
  ];

  testWidgets('Procedures list renders procedure cards via ResourceListView',
      (tester) async {
    await tester.pumpWidget(_app(procedures));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceListView<ProcedureListItem>), findsOneWidget);
    expect(find.text('Procedures'), findsOneWidget);
    expect(find.byKey(const ValueKey('procedure_card_p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('procedure_card_p2')), findsOneWidget);
  });

  testWidgets('search narrows procedures by name via procedures_search field',
      (tester) async {
    await tester.pumpWidget(_app(procedures));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('procedures_search')),
      'backup',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('procedure_card_p2')), findsOneWidget);
    expect(find.byKey(const ValueKey('procedure_card_p1')), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/widget/procedures_view_test.dart` / Expected: first test FAILS on `find.byType(ResourceListView<ProcedureListItem>)` with `Found 0 widgets with type "ResourceListView<ProcedureListItem>"`.

- [ ] **Step 3: Write minimal implementation**

Replace the ENTIRE content of `lib/features/procedures/presentation/views/procedures_list_view.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/procedures/presentation/widgets/procedure_card.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

/// View displaying the list of all procedures.
class ProceduresListView extends StatelessWidget {
  const ProceduresListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResourceListView<ProcedureListItem>(config: _proceduresListConfig);
  }
}

final _proceduresListConfig = ResourceListConfig<ProcedureListItem>(
  kind: ResourceKind.procedures,
  title: 'Procedures',
  resourceName: 'procedures',
  icon: AppIcons.procedures,
  markColor: AppTokens.resourceProcedures,
  searchFieldKey: const ValueKey('procedures_search'),
  skeletonTitle: 'Procedure name',
  skeletonSubtitle: 'Owner - Last run - Duration',
  skeletonChipLeft: 'Idle',
  skeletonChipRight: 'Steps 5',
  watchList: (ref) => ref.watch(proceduresProvider),
  refreshList: (ref) => ref.read(proceduresProvider.notifier).refresh(),
  invalidateList: (ref) => ref.invalidate(proceduresProvider),
  watchActionsState: (ref) => ref.watch(procedureActionsProvider),
  isTemplate: (item) => item.template,
  tagsOf: (item) => item.tags,
  searchFieldsOf: (item) => [
    item.name,
    item.info.state.name,
    item.info.stages.toString(),
  ],
  cardBuilder: (context, ref, item, displayTags) => ProcedureCard(
    procedure: item,
    displayTags: displayTags,
    onTap: () => context.push(
      '${AppRoutes.procedures}/${item.id}?name=${Uri.encodeComponent(item.name)}',
    ),
    onRun: () => _runProcedure(context, ref, item.id),
  ),
);

Future<void> _runProcedure(
  BuildContext context,
  WidgetRef ref,
  String procedureId,
) async {
  final actions = ref.read(procedureActionsProvider.notifier);
  final success = await actions.run(procedureId);

  if (context.mounted) {
    AppSnackBar.show(
      context,
      success ? 'Procedure started' : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}
```

Then delete the dead filter providers and regenerate:

```bash
rm lib/features/procedures/presentation/providers/procedures_filters_provider.dart
rm -f lib/features/procedures/presentation/providers/procedures_filters_provider.g.dart
fvm dart run build_runner build --delete-conflicting-outputs
```

Verify: `grep -rn "proceduresSearchQueryProvider\|proceduresTagFilterProvider\|proceduresTemplateFilterStateProvider\|procedures_filters_provider" lib test integration_test` must return no matches.

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/widget/procedures_view_test.dart` / Expected: `All tests passed!` (2 tests). Then `fvm flutter analyze` / Expected: `No issues found!`. Then `fvm flutter test` / Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/procedures/presentation/views/procedures_list_view.dart test/widget/procedures_view_test.dart
git rm lib/features/procedures/presentation/providers/procedures_filters_provider.dart
git commit -m "refactor: migrate procedures list to shared ResourceListView

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 8: Migrate Syncs

**Files:**
- Modify: `lib/features/syncs/presentation/views/syncs_list_view.dart` (replace the entire 731-line file with the config below)
- Delete: `lib/features/syncs/presentation/providers/syncs_filters_provider.dart` (and its generated `syncs_filters_provider.g.dart` from disk)
- Test: `test/widget/syncs_view_test.dart` (new)

**Interfaces:**
- Consumes (from Task 3): `ResourceListView<T>({required ResourceListConfig<T> config})` from `package:komodo_go/core/widgets/resource_list/resource_list_view.dart`; `ResourceListConfig<T>` from `package:komodo_go/shared/resources/models/resource_list_config.dart`.
- Consumes (from Task 1): `ResourceKind.syncs` from `package:komodo_go/shared/resources/models/resource_kind.dart`.
- Consumes (existing, unchanged): `syncsProvider` / `Syncs.refresh()`, `syncActionsProvider` / `SyncActions.run(String)` from `syncs_provider.dart`; `SyncCard` (params `sync`, `displayTags`, `onTap`, `onRun`; NOTE: SyncCard has no root ValueKey — assert by text) from `sync_card.dart`; `ResourceSyncListItem` (fields `id`, `name`, `template`, `tags`, `info.repo`, `info.branch`, `info.linkedRepo`, `info.gitProvider`, `info.resourcePath` — a `List<String>`, `info.state.name`); `AppRoutes.syncs`; `AppIcons.syncs`; `AppTokens.resourceSyncs`; `AppSnackBar`.
- Produces: `SyncsListView` (same public class, same file path — router untouched).

- [ ] **Step 1: Write the failing test**

Create `test/widget/syncs_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:komodo_go/features/syncs/presentation/views/syncs_list_view.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestSyncs extends Syncs {
  _TestSyncs(this._syncs);

  final List<ResourceSyncListItem> _syncs;

  @override
  Future<List<ResourceSyncListItem>> build() async => _syncs;
}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

Widget _app(List<ResourceSyncListItem> syncs) {
  return ProviderScope(
    overrides: [
      syncsProvider.overrideWith(() => _TestSyncs(syncs)),
      tagsProvider.overrideWith(() => _TestTags(const [])),
    ],
    child: const MaterialApp(home: SyncsListView()),
  );
}

void main() {
  final syncs = [
    ResourceSyncListItem.fromJson(<String, dynamic>{
      'id': 'sy1',
      'name': 'Sync One',
      'info': <String, dynamic>{},
    }),
    ResourceSyncListItem.fromJson(<String, dynamic>{
      'id': 'sy2',
      'name': 'Cluster State',
      'info': <String, dynamic>{'branch': 'release'},
    }),
  ];

  testWidgets('Syncs list renders sync cards via ResourceListView',
      (tester) async {
    await tester.pumpWidget(_app(syncs));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceListView<ResourceSyncListItem>), findsOneWidget);
    expect(find.text('Syncs'), findsOneWidget);
    // SyncCard has no root ValueKey; assert by visible name (same finder the
    // Patrol flow integration_test/resource_flows/syncs_run_test.dart uses).
    expect(find.text('Sync One'), findsOneWidget);
    expect(find.text('Cluster State'), findsOneWidget);
  });

  testWidgets('search matches sync info fields (branch) via syncs_search',
      (tester) async {
    await tester.pumpWidget(_app(syncs));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('syncs_search')),
      'release',
    );
    await tester.pumpAndSettle();

    expect(find.text('Cluster State'), findsOneWidget);
    expect(find.text('Sync One'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/widget/syncs_view_test.dart` / Expected: first test FAILS on `find.byType(ResourceListView<ResourceSyncListItem>)` with `Found 0 widgets with type "ResourceListView<ResourceSyncListItem>"`.

- [ ] **Step 3: Write minimal implementation**

Replace the ENTIRE content of `lib/features/syncs/presentation/views/syncs_list_view.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:komodo_go/features/syncs/presentation/widgets/sync_card.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

/// View displaying the list of all syncs.
class SyncsListView extends StatelessWidget {
  const SyncsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResourceListView<ResourceSyncListItem>(config: _syncsListConfig);
  }
}

final _syncsListConfig = ResourceListConfig<ResourceSyncListItem>(
  kind: ResourceKind.syncs,
  title: 'Syncs',
  resourceName: 'syncs',
  icon: AppIcons.syncs,
  markColor: AppTokens.resourceSyncs,
  searchFieldKey: const ValueKey('syncs_search'),
  skeletonTitle: 'Sync name',
  skeletonSubtitle: 'Repo - Server - Schedule',
  skeletonChipLeft: 'Idle',
  skeletonChipRight: 'Last run 2m',
  watchList: (ref) => ref.watch(syncsProvider),
  refreshList: (ref) => ref.read(syncsProvider.notifier).refresh(),
  invalidateList: (ref) => ref.invalidate(syncsProvider),
  watchActionsState: (ref) => ref.watch(syncActionsProvider),
  isTemplate: (item) => item.template,
  tagsOf: (item) => item.tags,
  searchFieldsOf: (item) => [
    item.name,
    item.info.repo,
    item.info.branch,
    item.info.linkedRepo,
    item.info.gitProvider,
    item.info.resourcePath.join(' '),
    item.info.state.name,
  ],
  cardBuilder: (context, ref, item, displayTags) => SyncCard(
    sync: item,
    displayTags: displayTags,
    onTap: () => context.push(
      '${AppRoutes.syncs}/${item.id}?name=${Uri.encodeComponent(item.name)}',
    ),
    onRun: () => _runSync(context, ref, item.id),
  ),
);

Future<void> _runSync(
  BuildContext context,
  WidgetRef ref,
  String syncId,
) async {
  final actions = ref.read(syncActionsProvider.notifier);
  final success = await actions.run(syncId);

  if (context.mounted) {
    AppSnackBar.show(
      context,
      success ? 'Sync started' : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}
```

Then delete the dead filter providers and regenerate:

```bash
rm lib/features/syncs/presentation/providers/syncs_filters_provider.dart
rm -f lib/features/syncs/presentation/providers/syncs_filters_provider.g.dart
fvm dart run build_runner build --delete-conflicting-outputs
```

Verify: `grep -rn "syncsSearchQueryProvider\|syncsTagFilterProvider\|syncsTemplateFilterStateProvider\|syncs_filters_provider" lib test integration_test` must return no matches. Also verify all five migrations are complete: `grep -rln "listenManual" lib/features/*/presentation/views/*s_list_view.dart` must return no matches for builds/repos/actions/procedures/syncs (deployments/stacks/servers/containers still have their own copies — out of scope).

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/widget/syncs_view_test.dart` / Expected: `All tests passed!` (2 tests). Then `fvm flutter analyze` / Expected: `No issues found!`. Then `fvm flutter test` / Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/syncs/presentation/views/syncs_list_view.dart test/widget/syncs_view_test.dart
git rm lib/features/syncs/presentation/providers/syncs_filters_provider.dart
git commit -m "refactor: migrate syncs list to shared ResourceListView

All five template-generation list views now share one scaffold.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Shared `ResourceActionExecutor` Mixin for the Five `*Actions` Notifiers

**Files:**
- Create: `lib/shared/resources/providers/resource_action_executor.dart`
- Modify: `lib/features/builds/presentation/providers/builds_provider.dart` (replace the `BuildActions` class, lines 49–123; `Builds`, `buildDetail`, `builderName` stay untouched)
- Modify: `lib/features/repos/presentation/providers/repos_provider.dart` (replace the `RepoActions` class, starting line 50)
- Modify: `lib/features/actions/presentation/providers/actions_provider.dart` (replace the `ActionActions` class, starting line 50)
- Modify: `lib/features/procedures/presentation/providers/procedures_provider.dart` (replace the `ProcedureActions` class, starting line 53)
- Modify: `lib/features/syncs/presentation/providers/syncs_provider.dart` (replace the `SyncActions` class, starting line 50)
- Test: `test/unit/shared/resources/resource_action_executor_test.dart` (new); existing safety net: `test/unit/features/{builds,repos,actions,procedures,syncs}/presentation/providers/*_provider_test.dart` must stay green unmodified.

**Interfaces:**
- Consumes: `Either<Failure, T>` from fpdart; `Failure` + `FailureX.displayMessage` from `lib/core/error/failures.dart`; `AsyncValue` (re-exported by `riverpod_annotation`).
- Produces: `mixin ResourceActionExecutor<RepoT>` with abstract members `AsyncValue<void> get state`, `set state(AsyncValue<void> value)`, `RepoT? readRepository()`, `void invalidateList()`, `bool get isMounted`, and concrete methods `Future<bool> executeAction(Future<Either<Failure, void>> Function(RepoT repo) action)` and `Future<T?> executeRequest<T>(Future<Either<Failure, T>> Function(RepoT repo) request)`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/shared/resources/resource_action_executor_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/shared/resources/providers/resource_action_executor.dart';

class _FakeRepo {}

class _Host with ResourceActionExecutor<_FakeRepo> {
  _Host({_FakeRepo? repo}) : _repo = repo;

  final _FakeRepo? _repo;
  bool mountedFlag = true;
  int invalidations = 0;

  @override
  AsyncValue<void> state = const AsyncValue.data(null);

  @override
  _FakeRepo? readRepository() => _repo;

  @override
  void invalidateList() => invalidations++;

  @override
  bool get isMounted => mountedFlag;
}

void main() {
  group('executeAction', () {
    test('returns true, resets state, invalidates list on success', () async {
      final host = _Host(repo: _FakeRepo());

      final ok = await host.executeAction((repo) async => const Right(null));

      expect(ok, isTrue);
      expect(host.state.hasError, isFalse);
      expect(host.state.isLoading, isFalse);
      expect(host.invalidations, 1);
    });

    test('returns false and surfaces failure message on Left', () async {
      final host = _Host(repo: _FakeRepo());

      final ok = await host.executeAction(
        (repo) async => const Left(Failure.server(message: 'boom')),
      );

      expect(ok, isFalse);
      expect(host.state.hasError, isTrue);
      expect(host.invalidations, 0);
    });

    test('returns false with auth error when repository is null', () async {
      final host = _Host();

      final ok = await host.executeAction((repo) async => const Right(null));

      expect(ok, isFalse);
      expect(host.state.hasError, isTrue);
      expect(host.state.error, 'Not authenticated');
    });

    test('bails out without touching state when unmounted mid-flight',
        () async {
      final host = _Host(repo: _FakeRepo());

      final ok = await host.executeAction((repo) async {
        host.mountedFlag = false;
        return const Right(null);
      });

      expect(ok, isFalse);
      expect(host.state.isLoading, isTrue);
      expect(host.invalidations, 0);
    });
  });

  group('executeRequest', () {
    test('returns the value and invalidates list on success', () async {
      final host = _Host(repo: _FakeRepo());

      final value = await host.executeRequest<int>(
        (repo) async => const Right(42),
      );

      expect(value, 42);
      expect(host.invalidations, 1);
    });

    test('returns null and surfaces failure on Left', () async {
      final host = _Host(repo: _FakeRepo());

      final value = await host.executeRequest<int>(
        (repo) async => const Left(Failure.server(message: 'boom')),
      );

      expect(value, isNull);
      expect(host.state.hasError, isTrue);
      expect(host.invalidations, 0);
    });

    test('returns null with auth error when repository is null', () async {
      final host = _Host();

      final value = await host.executeRequest<int>(
        (repo) async => const Right(42),
      );

      expect(value, isNull);
      expect(host.state.error, 'Not authenticated');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/unit/shared/resources/resource_action_executor_test.dart` / Expected: compilation failure — `Error: Error when reading 'lib/shared/resources/providers/resource_action_executor.dart': No such file or directory`.

- [ ] **Step 3: Write minimal implementation**

Create `lib/shared/resources/providers/resource_action_executor.dart`. The method bodies are the `_executeAction`/`_executeRequest` bodies duplicated across the five `*s_provider.dart` files (e.g. `builds_provider.dart:68-122`), with `ref.read(<repo>Provider)` → `readRepository()`, `ref.invalidate(<list>Provider)` → `invalidateList()`, and `ref.mounted` → `isMounted`:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Shared `_executeAction`/`_executeRequest` logic for the resource
/// `*Actions` notifiers (BuildActions, RepoActions, ActionActions,
/// ProcedureActions, SyncActions).
///
/// The host notifier provides `state` (inherited from its generated base
/// class) plus the three small hooks below.
mixin ResourceActionExecutor<RepoT> {
  /// Current action state; satisfied by the notifier's generated base class.
  AsyncValue<void> get state;
  set state(AsyncValue<void> value);

  /// Reads the feature repository; null when unauthenticated.
  RepoT? readRepository();

  /// Invalidates the feature list provider after a successful mutation.
  void invalidateList();

  /// Whether the host notifier is still mounted (`ref.mounted`).
  bool get isMounted;

  /// Runs a void execute call; returns true on success.
  Future<bool> executeAction(
    Future<Either<Failure, void>> Function(RepoT repo) action,
  ) async {
    final repository = readRepository();
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();

    final result = await action(repository);

    if (!isMounted) return false;

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        invalidateList();
        return true;
      },
    );
  }

  /// Runs a value-returning request; returns null on failure.
  Future<T?> executeRequest<T>(
    Future<Either<Failure, T>> Function(RepoT repo) request,
  ) async {
    final repository = readRepository();
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();

    final result = await request(repository);

    if (!isMounted) return null;

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return null;
      },
      (value) {
        state = const AsyncValue.data(null);
        invalidateList();
        return value;
      },
    );
  }
}
```

Then rewrite the five `*Actions` classes. Add `import 'package:komodo_go/shared/resources/providers/resource_action_executor.dart';` to each file and remove the imports the analyzer then flags as unused (`package:fpdart/fpdart.dart` and `package:komodo_go/core/error/failures.dart` — but keep them if anything else in the file still names those types).

`lib/features/builds/presentation/providers/builds_provider.dart` — replace `BuildActions` (keep the doc comment `/// Action state for build operations.`):

```dart
/// Action state for build operations.
@riverpod
class BuildActions extends _$BuildActions
    with ResourceActionExecutor<BuildRepository> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  BuildRepository? readRepository() => ref.read(buildRepositoryProvider);

  @override
  void invalidateList() => ref.invalidate(buildsProvider);

  @override
  bool get isMounted => ref.mounted;

  Future<bool> run(String buildIdOrName) =>
      executeAction((repo) => repo.runBuild(buildIdOrName));

  Future<bool> cancel(String buildIdOrName) =>
      executeAction((repo) => repo.cancelBuild(buildIdOrName));

  Future<KomodoBuild?> updateBuildConfig({
    required String buildId,
    required Map<String, dynamic> partialConfig,
  }) => executeRequest(
    (repo) => repo.updateBuildConfig(
      buildId: buildId,
      partialConfig: partialConfig,
    ),
  );
}
```

`lib/features/repos/presentation/providers/repos_provider.dart` — replace `RepoActions`:

```dart
/// Action state for repo operations.
@riverpod
class RepoActions extends _$RepoActions
    with ResourceActionExecutor<RepoRepository> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  RepoRepository? readRepository() => ref.read(repoRepositoryProvider);

  @override
  void invalidateList() => ref.invalidate(reposProvider);

  @override
  bool get isMounted => ref.mounted;

  Future<bool> clone(String repoIdOrName) =>
      executeAction((repo) => repo.cloneRepo(repoIdOrName));

  Future<bool> pull(String repoIdOrName) =>
      executeAction((repo) => repo.pullRepo(repoIdOrName));

  Future<bool> buildRepo(String repoIdOrName) =>
      executeAction((repo) => repo.buildRepo(repoIdOrName));

  Future<KomodoRepo?> updateRepoConfig({
    required String repoId,
    required Map<String, dynamic> partialConfig,
  }) => executeRequest(
    (repo) => repo.updateRepoConfig(
      repoId: repoId,
      partialConfig: partialConfig,
    ),
  );
}
```

`lib/features/actions/presentation/providers/actions_provider.dart` — replace `ActionActions`:

```dart
/// Action state for action operations.
@riverpod
class ActionActions extends _$ActionActions
    with ResourceActionExecutor<ActionRepository> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  ActionRepository? readRepository() => ref.read(actionRepositoryProvider);

  @override
  void invalidateList() => ref.invalidate(actionsProvider);

  @override
  bool get isMounted => ref.mounted;

  Future<bool> run(String actionIdOrName, {Map<String, dynamic>? args}) =>
      executeAction((repo) => repo.runAction(actionIdOrName, args: args));

  Future<KomodoAction?> updateActionConfig({
    required String actionId,
    required Map<String, dynamic> partialConfig,
  }) => executeRequest(
    (repo) => repo.updateActionConfig(
      actionId: actionId,
      partialConfig: partialConfig,
    ),
  );
}
```

`lib/features/procedures/presentation/providers/procedures_provider.dart` — replace `ProcedureActions`:

```dart
/// Action state for procedure operations.
@riverpod
class ProcedureActions extends _$ProcedureActions
    with ResourceActionExecutor<ProcedureRepository> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  ProcedureRepository? readRepository() =>
      ref.read(procedureRepositoryProvider);

  @override
  void invalidateList() => ref.invalidate(proceduresProvider);

  @override
  bool get isMounted => ref.mounted;

  Future<bool> run(String procedureIdOrName) =>
      executeAction((repo) => repo.runProcedure(procedureIdOrName));

  Future<KomodoProcedure?> updateProcedureConfig({
    required String procedureId,
    required Map<String, dynamic> partialConfig,
  }) => executeRequest(
    (repo) => repo.updateProcedureConfig(
      procedureId: procedureId,
      partialConfig: partialConfig,
    ),
  );
}
```

`lib/features/syncs/presentation/providers/syncs_provider.dart` — replace `SyncActions`:

```dart
/// Action state for sync operations.
@riverpod
class SyncActions extends _$SyncActions
    with ResourceActionExecutor<SyncRepository> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  SyncRepository? readRepository() => ref.read(syncRepositoryProvider);

  @override
  void invalidateList() => ref.invalidate(syncsProvider);

  @override
  bool get isMounted => ref.mounted;

  Future<bool> run(String syncIdOrName) =>
      executeAction((repo) => repo.runSync(syncIdOrName));

  Future<KomodoResourceSync?> updateSyncConfig({
    required String syncId,
    required Map<String, dynamic> partialConfig,
  }) => executeRequest(
    (repo) =>
        repo.updateSyncConfig(syncId: syncId, partialConfig: partialConfig),
  );
}
```

In every file the two private `_executeAction`/`_executeRequest` methods are deleted; all public method signatures and repository calls above are copied verbatim from the current sources (`repos_provider.dart:55-70`, `actions_provider.dart:55-66`, `procedures_provider.dart:58-69`, `syncs_provider.dart:55-63`). Do not change the exact repository-call expressions.

Then regenerate:

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/unit/shared/resources/resource_action_executor_test.dart` / Expected: `All tests passed!` (7 tests). Then run the untouched behavior safety net: `fvm flutter test test/unit/features/builds test/unit/features/repos test/unit/features/actions test/unit/features/procedures test/unit/features/syncs` / Expected: all green with zero modifications to those test files. Then `fvm flutter analyze` / Expected: `No issues found!`. Then `fvm flutter test` / Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/resources/providers/resource_action_executor.dart test/unit/shared/resources/resource_action_executor_test.dart lib/features/builds/presentation/providers/builds_provider.dart lib/features/repos/presentation/providers/repos_provider.dart lib/features/actions/presentation/providers/actions_provider.dart lib/features/procedures/presentation/providers/procedures_provider.dart lib/features/syncs/presentation/providers/syncs_provider.dart
git commit -m "refactor: dedupe resource *Actions notifiers via ResourceActionExecutor

The five identical _executeAction/_executeRequest bodies move into one
unit-tested mixin; existing per-feature provider tests unchanged.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Final Verification (after Task 9)

- [ ] `fvm flutter analyze` → `No issues found!`
- [ ] `fvm flutter test` → full suite green.
- [ ] Dead-code sweep returns nothing: `grep -rn "SearchQueryProvider\|TagFilterProvider\|TemplateFilterStateProvider" lib --include="*.dart" | grep -v ".g.dart" | grep -vE "containers|stacks|deployments|servers|resource_filters"`.
- [ ] Confirm deleted files are gone: `ls lib/features/{builds,repos,actions,procedures,syncs}/presentation/providers/ | grep filters` returns nothing.
- [ ] Manual smoke (optional but recommended, `fvm flutter run`): open each of the five lists; verify pull-to-refresh, search toggle + typing, filters panel (template menu + tag sheet), empty state, and one card action snackbar per screen.
- [ ] Patrol flows are exercised separately (`integration_test/resource_flows/`); they rely only on card widgets and navigation, both untouched.

## Line-Count Ledger (expected)

| Removed | ~lines | Added | ~lines |
|---|---|---|---|
| 5 list views (725–739 each) | 3,663 | 5 config views (~75–90 each) | 420 |
| 5 filters providers | 235 | shared filters provider | 55 |
| 5× `_execute*` bodies | 275 | `ResourceListView` + config model | 780 |
| | | `ResourceKind` + filtering + mixin | 190 |
| **Total removed** | **~4,170** | **Total added** | **~1,445** |

Net: ~2,700 handwritten lines removed (~3,000 including the five no-longer-generated `*_filters_provider.g.dart` files). A future sixth resource list is one ~80-line config file.




