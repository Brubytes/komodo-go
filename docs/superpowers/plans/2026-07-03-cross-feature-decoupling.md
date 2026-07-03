# Cross-Feature Decoupling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove direct feature-to-feature imports from feature, shared, and core implementation files by moving explicit cross-feature wiring into one composition layer and by extracting shared contracts for resource references, options, labels, and name resolution.

**Architecture:** `lib/shared` owns feature-agnostic resource contracts (`ResourceKind`, `ResourceRef`, resource labels/icons, target options, name resolver interfaces, and provider declarations) and never imports `lib/features`. `lib/composition` is the only non-router layer allowed to import multiple features; it statically wires feature repositories/providers into shared contracts, hub screens, and cross-resource detail pages. Feature packages either depend on their own feature, `lib/core`, `lib/shared`, or `lib/composition` entry points; no feature imports another feature directly.

**Tech Stack:** Flutter 3.38.9 via FVM, Riverpod v3 with `riverpod_annotation` codegen, freezed models (unchanged), fpdart `Either` repositories, `flutter_test` + `mocktail`, `very_good_analysis`.

## Global Constraints

- Prefix shell commands with `rtk`; prefix every Flutter/Dart command with `fvm` (for example `rtk fvm flutter test`, `rtk fvm flutter analyze`).
- This plan is behavior-preserving. Do not change route paths, ValueKeys, visible strings, sorting, filtering, refresh targets, cache behavior, or fallback labels.
- `lib/shared` must not import `package:komodo_go/features/...`.
- Cross-feature aggregation must go through `lib/composition/...` or `lib/core/router/app_router.dart`. No runtime plugin registration; all wiring is explicit static Riverpod/provider code.
- Break cycles by moving files to their true owner with `git mv`; do not duplicate widgets/providers just to avoid imports.
- After every task run `rtk fvm flutter analyze` and `rtk fvm flutter test`. Expected analyzer result: `No issues found!`.
- After any `@riverpod` addition/move/removal run `rtk fvm dart run build_runner build --delete-conflicting-outputs`. Generated `*.g.dart`/`*.freezed.dart` remain gitignored and are not edited by hand.
- One commit per task. Every commit message body must end with:

```text
Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

- Current measured cross-feature import-line edges: 179 across 28 files, using:

```bash
rtk rg -n "package:komodo_go/features/" lib/features lib/shared lib/core -g '!*.g.dart' -g '!*.freezed.dart'
```

- Projected final direct feature-import edges: 113 total, all inside the allow-list below; 0 outside the allow-list and 0 from `lib/shared`.
- Final architecture guard allow-list:
  - `lib/core/router/app_router.dart`
  - `lib/composition/resources/resource_catalog_provider.dart`
  - `lib/composition/resources/resource_name_resolver_provider.dart`
  - `lib/composition/resources/resource_tag_options_provider.dart`
  - `lib/composition/home/home_view.dart`
  - `lib/composition/home/widgets/home_dashboard_tiles.dart`
  - `lib/composition/resources/resources_view.dart`
  - `lib/composition/stacks/stack_updates_provider.dart`
  - `lib/composition/stacks/stack_updates_tab.dart`
  - `lib/composition/alerters/alerter_detail_view.dart`
  - `lib/composition/alerters/resource_targets_editor_sheet.dart`
  - `lib/composition/builds/build_detail_view.dart`
  - `lib/composition/builds/build_detail_sections.dart`
  - `lib/composition/containers/containers_provider.dart`
  - `lib/composition/containers/containers_view.dart`
  - `lib/composition/deployments/deployment_detail_view.dart`
  - `lib/composition/deployments/deployment_detail_sections.dart`
  - `lib/composition/deployments/deployments_list_view.dart`
  - `lib/composition/repos/repo_detail_view.dart`
  - `lib/composition/repos/repo_detail_sections.dart`
  - `lib/composition/settings/add_connection_sheet.dart`
  - `lib/composition/settings/connections_view.dart`
  - `lib/composition/settings/settings_view.dart`
  - `lib/composition/stacks/stack_config_editor.dart`
  - `lib/composition/stacks/stack_detail_view.dart`
  - `lib/composition/stacks/stacks_list_view.dart`
  - `lib/composition/syncs/sync_detail_view.dart`
  - `lib/composition/syncs/sync_detail_sections.dart`
  - `lib/composition/servers/servers_list_view.dart`

---

### Task 1: Shared Resource Contracts and Pure Helpers

**Files:**
- Modify: `lib/shared/resources/models/resource_kind.dart`
- Create: `lib/shared/resources/models/resource_ref.dart`
- Create: `lib/shared/resources/models/resource_option.dart`
- Create: `lib/shared/resources/resource_helpers.dart` (rewrite existing file in place)
- Test: `test/unit/shared/resources/resource_helpers_test.dart`

**Interfaces:**
- `ResourceKind` is extended from the existing enum; do not create a second enum.
- `ResourceRef` is the feature-agnostic identity: `kind + id`.
- `ResourceOption` is the feature-agnostic selector row: `ref + variant + name + icon`.
- `ResourceNameResolver` is a typedef consumed by UI/providers; the composition layer wires the implementation later.

- [ ] **Step 1: Write the failing helper test**

Create `test/unit/shared/resources/resource_helpers_test.dart`:

```dart
import 'package:flutter/material.dart';
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
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
rtk fvm flutter test test/unit/shared/resources/resource_helpers_test.dart
```

Expected: FAIL with missing `ResourceRef`, `ResourceOption`, and missing `ResourceKind` members.

- [ ] **Step 3: Extend `ResourceKind`**

Replace `lib/shared/resources/models/resource_kind.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

/// Identity of a Komodo resource family.
///
/// The first five values already key shared list filters. The remaining values
/// make all-resource selectors and name resolution feature-agnostic.
enum ResourceKind {
  servers('Server', 'Servers', AppIcons.server, AppTokens.resourceServers),
  stacks('Stack', 'Stacks', AppIcons.stacks, AppTokens.resourceStacks),
  deployments(
    'Deployment',
    'Deployments',
    AppIcons.deployments,
    AppTokens.resourceDeployments,
  ),
  builds('Build', 'Builds', AppIcons.builds, AppTokens.resourceBuilds),
  repos('Repo', 'Repos', AppIcons.repos, AppTokens.resourceRepos),
  procedures(
    'Procedure',
    'Procedures',
    AppIcons.procedures,
    AppTokens.resourceProcedures,
  ),
  actions('Action', 'Actions', AppIcons.actions, AppTokens.resourceActions),
  syncs('ResourceSync', 'Syncs', AppIcons.syncs, AppTokens.resourceSyncs),
  builders('Builder', 'Builders', AppIcons.factory, AppTokens.resourceBuilders),
  alerters(
    'Alerter',
    'Alerters',
    AppIcons.notifications,
    AppTokens.resourceAlerters,
  ),
  system('System', 'System', AppIcons.server, AppTokens.resourceServers),
  unknown('Resource', 'Resources', AppIcons.widgets, AppTokens.resourceServers);

  const ResourceKind(this.variant, this.label, this.icon, this.color);

  final String variant;
  final String label;
  final IconData icon;
  final Color color;
}

extension ResourceKindX on ResourceKind {
  static ResourceKind fromVariant(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', '');
    return switch (normalized) {
      'system' => ResourceKind.system,
      'server' => ResourceKind.servers,
      'stack' => ResourceKind.stacks,
      'deployment' => ResourceKind.deployments,
      'build' => ResourceKind.builds,
      'repo' => ResourceKind.repos,
      'procedure' => ResourceKind.procedures,
      'action' => ResourceKind.actions,
      'resourcesync' => ResourceKind.syncs,
      'builder' => ResourceKind.builders,
      'alerter' => ResourceKind.alerters,
      _ => ResourceKind.unknown,
    };
  }
}
```

- [ ] **Step 4: Add `ResourceRef`**

Create `lib/shared/resources/models/resource_ref.dart`:

```dart
import 'package:meta/meta.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';

@immutable
class ResourceRef {
  const ResourceRef({required this.kind, required this.id});

  final ResourceKind kind;
  final String id;

  String get normalizedId => id.trim();

  String get key => '${kind.variant.toLowerCase()}:$normalizedId';

  static ResourceRef? tryParseKey(String value) {
    final index = value.indexOf(':');
    if (index <= 0 || index == value.length - 1) return null;
    final variant = value.substring(0, index);
    final id = value.substring(index + 1).trim();
    if (id.isEmpty) return null;
    return ResourceRef(kind: ResourceKindX.fromVariant(variant), id: id);
  }

  @override
  bool operator ==(Object other) {
    return other is ResourceRef &&
        other.kind == kind &&
        other.normalizedId == normalizedId;
  }

  @override
  int get hashCode => Object.hash(kind, normalizedId);

  @override
  String toString() => key;
}
```

- [ ] **Step 5: Add `ResourceOption`**

Create `lib/shared/resources/models/resource_option.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';

class ResourceOption {
  const ResourceOption({required this.ref, required this.name});

  final ResourceRef ref;
  final String name;

  String get variant => ref.kind.variant;
  String get key => ref.key;
  IconData get icon => ref.kind.icon;
}
```

- [ ] **Step 6: Rewrite feature-free resource helpers**

Replace `lib/shared/resources/resource_helpers.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';

typedef ResourceNameResolver = Future<String> Function(ResourceRef ref);

IconData resourceIcon(ResourceKind kind) => kind.icon;

IconData resourceIconForVariant(String variant) {
  return ResourceKindX.fromVariant(variant).icon;
}

String resourceLabel({
  required ResourceRef ref,
  required Map<String, String> lookup,
  String? directName,
}) {
  final direct = directName?.trim();
  if (direct != null && direct.isNotEmpty) return direct;

  final lookupName = lookup[ref.key];
  if (lookupName != null && lookupName.trim().isNotEmpty) {
    return lookupName.trim();
  }

  return '${ref.kind.variant} ${_shortId(ref.normalizedId)}';
}

String _shortId(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 10) return trimmed;
  final start = trimmed.substring(0, 6);
  final end = trimmed.substring(trimmed.length - 4);
  return '$start...$end';
}
```

- [ ] **Step 7: Run focused test and full verification**

Run:

```bash
rtk fvm flutter test test/unit/shared/resources/resource_helpers_test.dart
rtk fvm flutter analyze
rtk fvm flutter test
```

Expected: focused test passes; analyzer reports `No issues found!`; full test suite passes.

- [ ] **Step 8: Commit**

```bash
rtk git add lib/shared/resources/models/resource_kind.dart lib/shared/resources/models/resource_ref.dart lib/shared/resources/models/resource_option.dart lib/shared/resources/resource_helpers.dart test/unit/shared/resources/resource_helpers_test.dart
rtk git commit -m "refactor: add shared resource contracts" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Static Resource Catalog Composition

**Files:**
- Create: `lib/composition/resources/resource_catalog_provider.dart`
- Modify: `lib/features/alerters/presentation/views/alerter_detail_view.dart`
- Modify: `lib/features/alerters/presentation/views/alerter_detail/resource_targets_editor_sheet.dart`
- Test: `test/unit/composition/resources/resource_catalog_provider_test.dart`

**Interfaces:**
- Composition catalog imports all resource providers/models and produces `AsyncValue<List<ResourceOption>>` and `Map<String, String>`.
- Alerter UI consumes shared options/lookup, removing all foreign feature imports from alerter presentation except its own alerter models/providers.

- [ ] **Step 1: Write failing catalog unit test**

Create `test/unit/composition/resources/resource_catalog_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
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
  });
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
rtk fvm flutter test test/unit/composition/resources/resource_catalog_provider_test.dart
```

Expected: FAIL until the `lib/composition/resources` directory and imports exist.

- [ ] **Step 3: Add the composition catalog**

Create `lib/composition/resources/resource_catalog_provider.dart`:

```dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/alerters/data/models/alerter_list_item.dart';
import 'package:komodo_go/features/alerters/presentation/providers/alerters_provider.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_option.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';

List<T> _asyncListOrEmpty<T>(AsyncValue<List<T>> async) {
  return async.maybeWhen(data: (value) => value, orElse: () => <T>[]);
}

List<ResourceOption> resourceOptionsFromLists({
  required List<Server> servers,
  required List<StackListItem> stacks,
  required List<Deployment> deployments,
  required List<BuildListItem> builds,
  required List<RepoListItem> repos,
  required List<ProcedureListItem> procedures,
  required List<ActionListItem> actions,
  required List<ResourceSyncListItem> syncs,
  required List<BuilderListItem> builders,
  required List<AlerterListItem> alerters,
}) {
  final options = <ResourceOption>[];

  void addAll<T>({
    required ResourceKind kind,
    required List<T> items,
    required String Function(T item) getId,
    required String Function(T item) getName,
  }) {
    for (final item in items) {
      final id = getId(item).trim();
      final name = getName(item).trim();
      if (id.isEmpty || name.isEmpty) continue;
      options.add(ResourceOption(ref: ResourceRef(kind: kind, id: id), name: name));
    }
  }

  addAll<Server>(
    kind: ResourceKind.servers,
    items: servers,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<StackListItem>(
    kind: ResourceKind.stacks,
    items: stacks,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<Deployment>(
    kind: ResourceKind.deployments,
    items: deployments,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<BuildListItem>(
    kind: ResourceKind.builds,
    items: builds,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<RepoListItem>(
    kind: ResourceKind.repos,
    items: repos,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<ProcedureListItem>(
    kind: ResourceKind.procedures,
    items: procedures,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<ActionListItem>(
    kind: ResourceKind.actions,
    items: actions,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<ResourceSyncListItem>(
    kind: ResourceKind.syncs,
    items: syncs,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<BuilderListItem>(
    kind: ResourceKind.builders,
    items: builders,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<AlerterListItem>(
    kind: ResourceKind.alerters,
    items: alerters,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );

  options.sort((a, b) {
    final typeSort = a.variant.compareTo(b.variant);
    if (typeSort != 0) return typeSort;
    return a.name.compareTo(b.name);
  });
  return options;
}

final resourceOptionsProvider = Provider<AsyncValue<List<ResourceOption>>>((ref) {
  final asyncValues = [
    ref.watch(serversProvider),
    ref.watch(stacksProvider),
    ref.watch(deploymentsProvider),
    ref.watch(buildsProvider),
    ref.watch(reposProvider),
    ref.watch(proceduresProvider),
    ref.watch(actionsProvider),
    ref.watch(syncsProvider),
    ref.watch(buildersProvider),
    ref.watch(alertersProvider),
  ];

  final hasLoading = asyncValues.any((value) => value.isLoading);
  final firstError = asyncValues.where((value) => value.hasError).firstOrNull;
  if (firstError != null && !hasLoading) {
    return AsyncValue.error(firstError.error!, firstError.stackTrace!);
  }

  final options = resourceOptionsFromLists(
    servers: _asyncListOrEmpty(ref.watch(serversProvider)),
    stacks: _asyncListOrEmpty(ref.watch(stacksProvider)),
    deployments: _asyncListOrEmpty(ref.watch(deploymentsProvider)),
    builds: _asyncListOrEmpty(ref.watch(buildsProvider)),
    repos: _asyncListOrEmpty(ref.watch(reposProvider)),
    procedures: _asyncListOrEmpty(ref.watch(proceduresProvider)),
    actions: _asyncListOrEmpty(ref.watch(actionsProvider)),
    syncs: _asyncListOrEmpty(ref.watch(syncsProvider)),
    builders: _asyncListOrEmpty(ref.watch(buildersProvider)),
    alerters: _asyncListOrEmpty(ref.watch(alertersProvider)),
  );

  return hasLoading ? AsyncValue.loading().copyWithPrevious(AsyncValue.data(options)) : AsyncValue.data(options);
});

final resourceNameLookupProvider = Provider<Map<String, String>>((ref) {
  final options = ref.watch(resourceOptionsProvider).maybeWhen(
        data: (value) => value,
        orElse: () => const <ResourceOption>[],
      );
  return {
    for (final option in options)
      if (option.name.trim().isNotEmpty) option.key: option.name.trim(),
  };
});
```

- [ ] **Step 4: Update `alerter_detail_view.dart` imports and lookup**

In `lib/features/alerters/presentation/views/alerter_detail_view.dart`, remove these imports:

```dart
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
```

Add:

```dart
import 'package:komodo_go/composition/resources/resource_catalog_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';
```

Replace the `resourceNameLookupMap = resourceNameLookup(...)` block with:

```dart
    final resourceNameLookupMap = ref.watch(resourceNameLookupProvider);
```

Replace both `PillData` mappings:

```dart
                    resourceLabel(entry, resourceNameLookupMap),
                    resourceIcon(entry.variant),
```

with:

```dart
                    resourceLabel(
                      ref: ResourceRef(
                        kind: ResourceKindX.fromVariant(entry.variant),
                        id: entry.value,
                      ),
                      directName: entry.name,
                      lookup: resourceNameLookupMap,
                    ),
                    resourceIconForVariant(entry.variant),
```

Remove the private `_asyncListOrEmpty<T>` helper from the bottom of the file if it is no longer referenced.

- [ ] **Step 5: Update `resource_targets_editor_sheet.dart` to consume catalog options**

In `lib/features/alerters/presentation/views/alerter_detail/resource_targets_editor_sheet.dart`, remove all foreign feature model/provider imports and add:

```dart
import 'package:komodo_go/composition/resources/resource_catalog_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_option.dart';
```

Inside `build`, replace all `ref.watch(...)` resource provider reads, the local `addOptions<T>` function, and all `addOptions` calls with:

```dart
    final optionsAsync = ref.watch(resourceOptionsProvider);
    final options = optionsAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const <ResourceOption>[],
    );
```

Replace `hasErrors` and `isLoading` with:

```dart
    final hasErrors = optionsAsync.hasError;
    final isLoading = optionsAsync.isLoading;
```

Change all `_ResourceOption` type references to `ResourceOption`. Replace `_toggleOption` with:

```dart
  void _toggleOption(ResourceOption option, bool next) {
    final nextItems = List<AlerterResourceTarget>.from(_items);
    final index = nextItems.indexWhere((item) => item.key == option.key);
    if (next) {
      if (index == -1) {
        nextItems.add(
          AlerterResourceTarget(
            variant: option.variant,
            value: option.ref.id,
            name: option.name,
          ),
        );
      }
    } else {
      if (index != -1) nextItems.removeAt(index);
    }
    setState(() => _items = nextItems);
  }
```

Delete the private `_ResourceOption` class and `_asyncListOrEmpty<T>` helper.

- [ ] **Step 6: Run build runner and verification**

Run:

```bash
rtk fvm dart run build_runner build --delete-conflicting-outputs
rtk fvm flutter test test/unit/composition/resources/resource_catalog_provider_test.dart
rtk fvm flutter analyze
rtk fvm flutter test
```

Expected: tests pass; analyzer reports `No issues found!`; full suite passes.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/composition/resources/resource_catalog_provider.dart lib/features/alerters/presentation/views/alerter_detail_view.dart lib/features/alerters/presentation/views/alerter_detail/resource_targets_editor_sheet.dart test/unit/composition/resources/resource_catalog_provider_test.dart
rtk git commit -m "refactor: compose all-resource catalog outside features" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Move Resource Navigation State and Dashboard Card to Shared Owners

**Files:**
- Move: `lib/features/resources/presentation/providers/resources_tab_provider.dart` -> `lib/shared/resources/providers/resources_target_provider.dart`
- Move: `lib/features/home/presentation/views/home/home_stat_card.dart` -> `lib/core/widgets/home_stat_card.dart`
- Modify imports in files that reference the moved files.

**Interfaces:**
- `ResourceType` remains the enum used by home/resources navigation and keeps labels/icons/colors unchanged.
- `resourcesTargetProvider` remains keepAlive and behavior-preserved.

- [ ] **Step 1: Move files**

Run:

```bash
rtk mkdir -p lib/shared/resources/providers
rtk git mv lib/features/resources/presentation/providers/resources_tab_provider.dart lib/shared/resources/providers/resources_target_provider.dart
rtk git mv lib/features/home/presentation/views/home/home_stat_card.dart lib/core/widgets/home_stat_card.dart
```

- [ ] **Step 2: Update `part` directive**

In `lib/shared/resources/providers/resources_target_provider.dart`, replace:

```dart
part 'resources_tab_provider.g.dart';
```

with:

```dart
part 'resources_target_provider.g.dart';
```

- [ ] **Step 3: Rewrite import paths**

Replace:

```dart
import 'package:komodo_go/features/resources/presentation/providers/resources_tab_provider.dart';
```

with:

```dart
import 'package:komodo_go/shared/resources/providers/resources_target_provider.dart';
```

in:
- `lib/features/home/presentation/views/home_view.dart`
- `lib/features/resources/presentation/views/resources_view.dart`

Replace:

```dart
import 'package:komodo_go/features/home/presentation/views/home/home_stat_card.dart';
```

with:

```dart
import 'package:komodo_go/core/widgets/home_stat_card.dart';
```

in:
- `lib/features/resources/presentation/views/resources_view.dart`

- [ ] **Step 4: Regenerate Riverpod output and verify**

Run:

```bash
rtk fvm dart run build_runner build --delete-conflicting-outputs
rtk fvm flutter analyze
rtk fvm flutter test
```

Expected: analyzer reports `No issues found!`; full test suite passes.

- [ ] **Step 5: Commit**

```bash
rtk git add lib/shared/resources/providers/resources_target_provider.dart lib/core/widgets/home_stat_card.dart lib/features/home/presentation/views/home_view.dart lib/features/resources/presentation/views/resources_view.dart
rtk git commit -m "refactor: move resource navigation primitives" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Move Home and Resources Hub Screens into Composition

**Files:**
- Move: `lib/features/home/presentation/views/home_view.dart` -> `lib/composition/home/home_view.dart`
- Move: `lib/features/home/presentation/views/home/home_dashboard_tiles.dart` -> `lib/composition/home/widgets/home_dashboard_tiles.dart`
- Move: `lib/features/home/presentation/views/home/home_sections.dart` -> `lib/composition/home/widgets/home_sections.dart`
- Move: `lib/features/resources/presentation/views/resources_view.dart` -> `lib/composition/resources/resources_view.dart`
- Modify: `lib/core/router/app_router.dart`

**Interfaces:**
- Public widget names remain `HomeView` and `ResourcesView`.
- Route paths and navigation behavior remain unchanged.

- [ ] **Step 1: Move hub files**

Run:

```bash
rtk mkdir -p lib/composition/home/widgets lib/composition/resources
rtk git mv lib/features/home/presentation/views/home_view.dart lib/composition/home/home_view.dart
rtk git mv lib/features/home/presentation/views/home/home_dashboard_tiles.dart lib/composition/home/widgets/home_dashboard_tiles.dart
rtk git mv lib/features/home/presentation/views/home/home_sections.dart lib/composition/home/widgets/home_sections.dart
rtk git mv lib/features/resources/presentation/views/resources_view.dart lib/composition/resources/resources_view.dart
```

- [ ] **Step 2: Update moved home imports**

In `lib/composition/home/home_view.dart`, replace:

```dart
import 'package:komodo_go/features/home/presentation/views/home/home_dashboard_tiles.dart';
import 'package:komodo_go/features/home/presentation/views/home/home_sections.dart';
```

with:

```dart
import 'package:komodo_go/composition/home/widgets/home_dashboard_tiles.dart';
import 'package:komodo_go/composition/home/widgets/home_sections.dart';
```

Ensure the moved file already imports:

```dart
import 'package:komodo_go/shared/resources/providers/resources_target_provider.dart';
```

and does not import `features/resources/presentation/providers/resources_tab_provider.dart`.

- [ ] **Step 3: Update router imports**

In `lib/core/router/app_router.dart`, replace:

```dart
import 'package:komodo_go/features/home/presentation/views/home_view.dart';
import 'package:komodo_go/features/resources/presentation/views/resources_view.dart';
```

with:

```dart
import 'package:komodo_go/composition/home/home_view.dart';
import 'package:komodo_go/composition/resources/resources_view.dart';
```

- [ ] **Step 4: Verify**

Run:

```bash
rtk fvm flutter analyze
rtk fvm flutter test
```

Expected: analyzer reports `No issues found!`; full test suite passes.

- [ ] **Step 5: Commit**

```bash
rtk git add lib/composition/home lib/composition/resources/resources_view.dart lib/core/router/app_router.dart
rtk git commit -m "refactor: move dashboard hubs to composition" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Move Stack Updates Wiring Out of Feature Cycle

**Files:**
- Move: `lib/features/notifications/presentation/providers/stack_updates_provider.dart` -> `lib/composition/stacks/stack_updates_provider.dart`
- Create: `lib/composition/stacks/stack_updates_tab.dart`
- Modify: `lib/features/stacks/presentation/views/stack_detail_view.dart`

**Interfaces:**
- `stackUpdatesProvider(stackId)` keeps the same provider name and pagination behavior.
- `StackUpdatesTab` owns the notifications update tile composition used by stack detail.

- [ ] **Step 1: Move provider**

Run:

```bash
rtk mkdir -p lib/composition/stacks
rtk git mv lib/features/notifications/presentation/providers/stack_updates_provider.dart lib/composition/stacks/stack_updates_provider.dart
```

- [ ] **Step 2: Update provider `part` directive**

In `lib/composition/stacks/stack_updates_provider.dart`, replace:

```dart
part 'stack_updates_provider.g.dart';
```

with the same line if unchanged; the generated part basename stays valid after the move:

```dart
part 'stack_updates_provider.g.dart';
```

- [ ] **Step 3: Add stack updates tab composition widget**

Create `lib/composition/stacks/stack_updates_tab.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/stacks/stack_updates_provider.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/features/notifications/presentation/views/notifications/notifications_sections.dart'
    show
        NotificationsEmptyState,
        NotificationsErrorState,
        PaginationFooter,
        UpdateTile;

class StackUpdatesTab extends ConsumerWidget {
  const StackUpdatesTab({required this.stackId, super.key});

  final String stackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stackUpdatesAsync = ref.watch(stackUpdatesProvider(stackId));

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(stackUpdatesProvider(stackId).notifier).refresh();
      },
      child: stackUpdatesAsync.when(
        data: (state) {
          if (state.items.isEmpty) {
            return DetailTabScrollView.box(
              child: const NotificationsEmptyState(
                icon: AppIcons.updateAvailable,
                title: 'No updates',
                description: 'No recent activity for this stack.',
              ),
            );
          }

          final itemCount = state.items.length + (state.nextPage == null ? 0 : 1);
          final sliverChildCount = itemCount == 0 ? 0 : itemCount * 2 - 1;

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
                unawaited(
                  ref.read(stackUpdatesProvider(stackId).notifier).fetchNextPage(),
                );
              }
              return false;
            },
            child: DetailTabScrollView(
              scrollKey: PageStorageKey('stack_${stackId}_updates'),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index.isOdd) return const Gap(12);

                  final itemIndex = index ~/ 2;
                  final isFooter = itemIndex >= state.items.length;
                  if (isFooter) {
                    return PaginationFooter(
                      isLoading: state.isLoadingMore,
                      onLoadMore: () => ref
                          .read(stackUpdatesProvider(stackId).notifier)
                          .fetchNextPage(),
                    );
                  }

                  final update = state.items[itemIndex];
                  return UpdateTile(update: update);
                }, childCount: sliverChildCount),
              ),
            ),
          );
        },
        loading: () => DetailTabScrollView.box(
          padding: EdgeInsets.zero,
          child: const AppSkeletonList(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          ),
        ),
        error: (error, _) => DetailTabScrollView.box(
          padding: EdgeInsets.zero,
          child: NotificationsErrorState(
            title: 'Failed to load updates',
            message: error.toString(),
            onRetry: () => ref.invalidate(stackUpdatesProvider(stackId)),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Simplify `stack_detail_view.dart` imports and body**

In `lib/features/stacks/presentation/views/stack_detail_view.dart`, remove:

```dart
import 'package:komodo_go/features/notifications/presentation/providers/stack_updates_provider.dart';
import 'package:komodo_go/features/notifications/presentation/views/notifications/notifications_sections.dart'
    show
        NotificationsEmptyState,
        NotificationsErrorState,
        PaginationFooter,
        UpdateTile;
```

Add:

```dart
import 'package:komodo_go/composition/stacks/stack_updates_tab.dart';
```

Remove:

```dart
    final stackUpdatesAsync = ref.watch(stackUpdatesProvider(widget.stackId));
```

Replace the entire updates tab `_KeepAlive(child: RefreshIndicator(...))` block with:

```dart
                _KeepAlive(child: StackUpdatesTab(stackId: widget.stackId)),
```

- [ ] **Step 5: Regenerate and verify**

Run:

```bash
rtk fvm dart run build_runner build --delete-conflicting-outputs
rtk fvm flutter analyze
rtk fvm flutter test
```

Expected: analyzer reports `No issues found!`; full test suite passes.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/composition/stacks/stack_updates_provider.dart lib/composition/stacks/stack_updates_tab.dart lib/features/stacks/presentation/views/stack_detail_view.dart
rtk git commit -m "refactor: compose stack updates outside features" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Decouple Notification Target Name Resolution

**Files:**
- Create: `lib/shared/resources/providers/resource_name_resolver_provider.dart`
- Create: `lib/composition/resources/resource_name_resolver_provider.dart`
- Modify: `lib/features/notifications/presentation/providers/target_display_name_provider.dart`
- Modify: `lib/features/notifications/presentation/views/notifications/notifications_sections.dart`
- Test: `test/unit/shared/resources/resource_ref_test.dart`

**Interfaces:**
- Notifications convert their `ResourceTarget` to shared `ResourceRef`.
- Composition wires the actual repository lookups.
- Cache behavior remains owned by notifications (`targetNameCacheProvider` unchanged).

- [ ] **Step 1: Add focused conversion test**

Create `test/unit/shared/resources/resource_ref_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';

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
}
```

- [ ] **Step 2: Add shared resolver provider declaration**

Create `lib/shared/resources/providers/resource_name_resolver_provider.dart`:

```dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';

typedef ResourceNameResolver = Future<String?> Function(ResourceRef ref);

final resourceNameResolverProvider = Provider<ResourceNameResolver>((ref) {
  return (resourceRef) async => null;
});
```

- [ ] **Step 3: Add composition resolver wiring**

Create `lib/composition/resources/resource_name_resolver_provider.dart`:

```dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
import 'package:komodo_go/features/procedures/data/repositories/procedure_repository.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';
import 'package:komodo_go/shared/resources/providers/resource_name_resolver_provider.dart';

final composedResourceNameResolverProvider = Provider<ResourceNameResolver>((ref) {
  return (resourceRef) => _fetchName(ref, resourceRef);
});

Future<String?> _fetchName(Ref ref, ResourceRef resourceRef) async {
  switch (resourceRef.kind) {
    case ResourceKind.system:
      return 'System';
    case ResourceKind.servers:
      final repo = ref.watch(serverRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getServer(resourceRef.id);
      return result.fold((_) => null, (server) => server.name);
    case ResourceKind.stacks:
      final repo = ref.watch(stackRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getStack(resourceRef.id);
      return result.fold((_) => null, (stack) => stack.name);
    case ResourceKind.deployments:
      final repo = ref.watch(deploymentRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getDeployment(resourceRef.id);
      return result.fold((_) => null, (deployment) => deployment.name);
    case ResourceKind.builds:
      final repo = ref.watch(buildRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getBuild(resourceRef.id);
      return result.fold((_) => null, (build) => build.name);
    case ResourceKind.repos:
      final repo = ref.watch(repoRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getRepo(resourceRef.id);
      return result.fold((_) => null, (repo) => repo.name);
    case ResourceKind.procedures:
      final repo = ref.watch(procedureRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getProcedure(resourceRef.id);
      return result.fold((_) => null, (procedure) => procedure.name);
    case ResourceKind.actions:
      final repo = ref.watch(actionRepositoryProvider);
      if (repo == null) return null;
      final result = await repo.getAction(resourceRef.id);
      return result.fold((_) => null, (action) => action.name);
    case ResourceKind.builders:
    case ResourceKind.alerters:
    case ResourceKind.syncs:
    case ResourceKind.unknown:
      return null;
  }
}
```

- [ ] **Step 4: Update notification target display provider**

In `lib/features/notifications/presentation/providers/target_display_name_provider.dart`, remove all feature repository imports and add:

```dart
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';
import 'package:komodo_go/shared/resources/providers/resource_name_resolver_provider.dart';
```

Replace `_fetchName` with:

```dart
Future<String> _fetchName(Ref ref, ResourceTarget target) async {
  final resolver = ref.watch(resourceNameResolverProvider);
  final name = await resolver(_resourceRefFor(target));
  final trimmed = name?.trim();
  return trimmed == null || trimmed.isEmpty ? target.displayName : trimmed;
}

ResourceRef _resourceRefFor(ResourceTarget target) {
  return ResourceRef(kind: _kindFor(target.type), id: target.id);
}

ResourceKind _kindFor(ResourceTargetType type) {
  return switch (type) {
    ResourceTargetType.system => ResourceKind.system,
    ResourceTargetType.server => ResourceKind.servers,
    ResourceTargetType.stack => ResourceKind.stacks,
    ResourceTargetType.deployment => ResourceKind.deployments,
    ResourceTargetType.build => ResourceKind.builds,
    ResourceTargetType.repo => ResourceKind.repos,
    ResourceTargetType.procedure => ResourceKind.procedures,
    ResourceTargetType.action => ResourceKind.actions,
    ResourceTargetType.builder => ResourceKind.builders,
    ResourceTargetType.alerter => ResourceKind.alerters,
    ResourceTargetType.resourceSync => ResourceKind.syncs,
    ResourceTargetType.unknown => ResourceKind.unknown,
  };
}
```

- [ ] **Step 5: Override resolver at composition roots**

In `lib/core/router/app_router.dart`, add:

```dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_name_resolver_provider.dart';
import 'package:komodo_go/shared/resources/providers/resource_name_resolver_provider.dart';
```

Replace the notifications route page builder:

```dart
pageBuilder: (context, state) =>
    _noTransitionTabPage(const NotificationsView()),
```

with:

```dart
pageBuilder: (context, state) => _noTransitionTabPage(
  ProviderScope(
    overrides: [
      resourceNameResolverProvider.overrideWith(
        (ref) => ref.watch(composedResourceNameResolverProvider),
      ),
    ],
    child: const NotificationsView(),
  ),
),
```

In `lib/composition/stacks/stack_updates_tab.dart`, add:

```dart
import 'package:komodo_go/composition/resources/resource_name_resolver_provider.dart';
import 'package:komodo_go/shared/resources/providers/resource_name_resolver_provider.dart';
```

Then wrap the existing `RefreshIndicator` return value. Replace:

```dart
    return RefreshIndicator(
```

with:

```dart
    return ProviderScope(
      overrides: [
        resourceNameResolverProvider.overrideWith(
          (ref) => ref.watch(composedResourceNameResolverProvider),
        ),
      ],
      child: RefreshIndicator(
```

and add the matching close at the end of `build`:

```dart
      ),
    ),
```

- [ ] **Step 6: Regenerate and verify**

Run:

```bash
rtk fvm dart run build_runner build --delete-conflicting-outputs
rtk fvm flutter test test/unit/shared/resources/resource_ref_test.dart
rtk fvm flutter analyze
rtk fvm flutter test
```

Expected: tests pass; analyzer reports `No issues found!`; full suite passes.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/shared/resources/providers/resource_name_resolver_provider.dart lib/composition/resources/resource_name_resolver_provider.dart lib/features/notifications/presentation/providers/target_display_name_provider.dart lib/core/router/app_router.dart test/unit/shared/resources/resource_ref_test.dart
rtk git commit -m "refactor: invert notification target name lookup" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Move Cross-Resource Detail and Settings Screens into Composition

**Files:**
- Move cross-feature detail/list/settings/containers files listed below.
- Modify: `lib/core/router/app_router.dart`
- Modify imports in moved files only.

**Interfaces:**
- Public widget class names remain unchanged.
- `app_router.dart` gets import-path updates only; route constants and route builders remain behavior-preserved.

- [ ] **Step 1: Move detail/list files that aggregate other features**

Run:

```bash
rtk mkdir -p lib/composition/builds lib/composition/containers lib/composition/deployments lib/composition/repos lib/composition/settings lib/composition/stacks lib/composition/syncs lib/composition/servers lib/composition/alerters
rtk git mv lib/features/alerters/presentation/views/alerter_detail_view.dart lib/composition/alerters/alerter_detail_view.dart
rtk git mv lib/features/alerters/presentation/views/alerter_detail/resource_targets_editor_sheet.dart lib/composition/alerters/resource_targets_editor_sheet.dart
rtk git mv lib/features/builds/presentation/views/build_detail_view.dart lib/composition/builds/build_detail_view.dart
rtk git mv lib/features/builds/presentation/views/build_detail/build_detail_sections.dart lib/composition/builds/build_detail_sections.dart
rtk git mv lib/features/containers/presentation/providers/containers_provider.dart lib/composition/containers/containers_provider.dart
rtk git mv lib/features/containers/presentation/views/containers_view.dart lib/composition/containers/containers_view.dart
rtk git mv lib/features/deployments/presentation/views/deployment_detail_view.dart lib/composition/deployments/deployment_detail_view.dart
rtk git mv lib/features/deployments/presentation/views/deployment_detail/deployment_detail_sections.dart lib/composition/deployments/deployment_detail_sections.dart
rtk git mv lib/features/deployments/presentation/views/deployments_list_view.dart lib/composition/deployments/deployments_list_view.dart
rtk git mv lib/features/repos/presentation/views/repo_detail_view.dart lib/composition/repos/repo_detail_view.dart
rtk git mv lib/features/repos/presentation/views/repo_detail/repo_detail_sections.dart lib/composition/repos/repo_detail_sections.dart
rtk git mv lib/features/settings/presentation/widgets/add_connection_sheet.dart lib/composition/settings/add_connection_sheet.dart
rtk git mv lib/features/settings/presentation/views/connections_view.dart lib/composition/settings/connections_view.dart
rtk git mv lib/features/settings/presentation/views/settings_view.dart lib/composition/settings/settings_view.dart
rtk git mv lib/features/stacks/presentation/views/stack_detail/stack_config_editor.dart lib/composition/stacks/stack_config_editor.dart
rtk git mv lib/features/stacks/presentation/views/stack_detail_view.dart lib/composition/stacks/stack_detail_view.dart
rtk git mv lib/features/stacks/presentation/views/stacks_list_view.dart lib/composition/stacks/stacks_list_view.dart
rtk git mv lib/features/syncs/presentation/views/sync_detail_view.dart lib/composition/syncs/sync_detail_view.dart
rtk git mv lib/features/syncs/presentation/views/sync_detail/sync_detail_sections.dart lib/composition/syncs/sync_detail_sections.dart
rtk git mv lib/features/servers/presentation/views/servers_list_view.dart lib/composition/servers/servers_list_view.dart
```

- [ ] **Step 2: Rewrite internal moved-file imports**

Apply these exact import rewrites:

```text
lib/composition/alerters/alerter_detail_view.dart:
  features/alerters/presentation/views/alerter_detail/resource_targets_editor_sheet.dart -> composition/alerters/resource_targets_editor_sheet.dart

lib/composition/builds/build_detail_view.dart:
  features/builds/presentation/views/build_detail/build_detail_sections.dart -> composition/builds/build_detail_sections.dart

lib/composition/deployments/deployment_detail_view.dart:
  features/builds/presentation/views/build_detail/build_detail_sections.dart -> composition/builds/build_detail_sections.dart
  features/deployments/presentation/views/deployment_detail/deployment_detail_sections.dart -> composition/deployments/deployment_detail_sections.dart

lib/composition/repos/repo_detail_view.dart:
  features/repos/presentation/views/repo_detail/repo_detail_sections.dart -> composition/repos/repo_detail_sections.dart

lib/composition/settings/connections_view.dart:
  features/settings/presentation/widgets/add_connection_sheet.dart -> composition/settings/add_connection_sheet.dart

lib/composition/stacks/stack_detail_view.dart:
  features/stacks/presentation/views/stack_detail/stack_config_editor.dart -> composition/stacks/stack_config_editor.dart
  composition/stacks/stack_updates_tab.dart stays imported from Task 5

lib/composition/syncs/sync_detail_view.dart:
  features/syncs/presentation/views/sync_detail/sync_detail_sections.dart -> composition/syncs/sync_detail_sections.dart
```

- [ ] **Step 3: Rewrite feature imports that now point to moved composition providers**

Replace every import of:

```dart
import 'package:komodo_go/features/containers/presentation/providers/containers_provider.dart';
```

with:

```dart
import 'package:komodo_go/composition/containers/containers_provider.dart';
```

Current known files:
- `lib/core/router/app_router.dart`
- `lib/composition/containers/containers_view.dart`
- `lib/features/containers/presentation/views/container_detail_view.dart`

- [ ] **Step 4: Update router imports**

In `lib/core/router/app_router.dart`, replace imports for moved views:

```dart
import 'package:komodo_go/features/alerters/presentation/views/alerter_detail_view.dart';
import 'package:komodo_go/features/builds/presentation/views/build_detail_view.dart';
import 'package:komodo_go/features/containers/presentation/views/containers_view.dart';
import 'package:komodo_go/features/deployments/presentation/views/deployment_detail_view.dart';
import 'package:komodo_go/features/deployments/presentation/views/deployments_list_view.dart';
import 'package:komodo_go/features/repos/presentation/views/repo_detail_view.dart';
import 'package:komodo_go/features/servers/presentation/views/servers_list_view.dart';
import 'package:komodo_go/features/settings/presentation/views/connections_view.dart';
import 'package:komodo_go/features/settings/presentation/views/settings_view.dart';
import 'package:komodo_go/features/stacks/presentation/views/stack_detail_view.dart';
import 'package:komodo_go/features/stacks/presentation/views/stacks_list_view.dart';
import 'package:komodo_go/features/syncs/presentation/views/sync_detail_view.dart';
```

with:

```dart
import 'package:komodo_go/composition/alerters/alerter_detail_view.dart';
import 'package:komodo_go/composition/builds/build_detail_view.dart';
import 'package:komodo_go/composition/containers/containers_view.dart';
import 'package:komodo_go/composition/deployments/deployment_detail_view.dart';
import 'package:komodo_go/composition/deployments/deployments_list_view.dart';
import 'package:komodo_go/composition/repos/repo_detail_view.dart';
import 'package:komodo_go/composition/servers/servers_list_view.dart';
import 'package:komodo_go/composition/settings/connections_view.dart';
import 'package:komodo_go/composition/settings/settings_view.dart';
import 'package:komodo_go/composition/stacks/stack_detail_view.dart';
import 'package:komodo_go/composition/stacks/stacks_list_view.dart';
import 'package:komodo_go/composition/syncs/sync_detail_view.dart';
```

- [ ] **Step 5: Regenerate and verify**

Run:

```bash
rtk fvm dart run build_runner build --delete-conflicting-outputs
rtk fvm flutter analyze
rtk fvm flutter test
```

Expected: analyzer reports `No issues found!`; full test suite passes.

- [ ] **Step 6: Commit**

```bash
rtk git add lib/composition lib/core/router/app_router.dart lib/features/containers/presentation/views/container_detail_view.dart
rtk git commit -m "refactor: move cross-resource screens to composition" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Remove Remaining Core-to-Feature Coupling

**Files:**
- Modify: `lib/core/providers/demo_mode_provider.dart`
- Move: `lib/features/settings/presentation/providers/theme_provider.dart` -> `lib/core/providers/theme_provider.dart`
- Modify: `lib/core/widgets/resource_list/resource_list_view.dart`
- Modify: `lib/shared/resources/models/resource_list_config.dart`
- Modify feature/composition list configs using `ResourceListView`
- Create: `lib/composition/resources/resource_tag_options_provider.dart`

**Interfaces:**
- Demo mode clears the active connection through core connection providers, matching the current `Auth.logout()` side effects without importing auth.
- Theme mode is app-wide state, so it moves from settings feature into core providers.
- `ResourceListView` no longer imports tags feature provider; tag options are supplied by config/composition.

- [ ] **Step 1: Update demo mode provider**

In `lib/core/providers/demo_mode_provider.dart`, replace:

```dart
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
```

with no replacement import.

Replace:

```dart
        await ref.read(authProvider.notifier).logout();
```

with:

```dart
        await ref.read(connectionsProvider.notifier).setActiveConnection(null);
```

- [ ] **Step 2: Move theme provider to core**

Run:

```bash
rtk git mv lib/features/settings/presentation/providers/theme_provider.dart lib/core/providers/theme_provider.dart
```

In `lib/core/providers/theme_provider.dart`, keep the existing part directive basename:

```dart
part 'theme_provider.g.dart';
```

Replace every import of:

```dart
import 'package:komodo_go/features/settings/presentation/providers/theme_provider.dart';
```

with:

```dart
import 'package:komodo_go/core/providers/theme_provider.dart';
```

Known files:
- `lib/app.dart`
- `lib/composition/settings/settings_view.dart` after Task 7

- [ ] **Step 3: Add tag options composition provider**

Create `lib/composition/resources/resource_tag_options_provider.dart`:

```dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/filters/tag_filter_sheet.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

final resourceTagOptionsProvider = Provider<AsyncValue<List<TagOption>>>((ref) {
  return ref.watch(tagsProvider).whenData(
        (tags) => [
          for (final tag in tags)
            if (tag.name.trim().isNotEmpty)
              TagOption(id: tag.id, name: tag.name.trim()),
        ],
      );
});
```

- [ ] **Step 4: Extend resource list config**

In `lib/shared/resources/models/resource_list_config.dart`, add constructor parameter:

```dart
    required this.watchTagOptions,
```

Add field:

```dart
  /// Watches globally configured tag options for this list.
  final AsyncValue<List<TagOption>> Function(WidgetRef ref) watchTagOptions;
```

Add import:

```dart
import 'package:komodo_go/core/widgets/filters/tag_filter_sheet.dart';
```

- [ ] **Step 5: Remove tags provider from core resource list widget**

In `lib/core/widgets/resource_list/resource_list_view.dart`, remove:

```dart
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
```

Replace:

```dart
    final tagsAsync = ref.watch(tagsProvider);
```

with:

```dart
    final tagsAsync = config.watchTagOptions(ref);
```

- [ ] **Step 6: Add `watchTagOptions` to every `ResourceListConfig`**

In each file that constructs `ResourceListConfig`, add:

```dart
import 'package:komodo_go/composition/resources/resource_tag_options_provider.dart';
```

and add this constructor argument:

```dart
      watchTagOptions: (ref) => ref.watch(resourceTagOptionsProvider),
```

Known files:
- `lib/features/actions/presentation/views/actions_list_view.dart`
- `lib/features/builds/presentation/views/builds_list_view.dart`
- `lib/features/procedures/presentation/views/procedures_list_view.dart`
- `lib/features/repos/presentation/views/repos_list_view.dart`
- `lib/features/syncs/presentation/views/syncs_list_view.dart`

- [ ] **Step 7: Regenerate and verify**

Run:

```bash
rtk fvm dart run build_runner build --delete-conflicting-outputs
rtk fvm flutter analyze
rtk fvm flutter test
```

Expected: analyzer reports `No issues found!`; full test suite passes.

- [ ] **Step 8: Commit**

```bash
rtk git add lib/core/providers/demo_mode_provider.dart lib/core/providers/theme_provider.dart lib/app.dart lib/composition/settings/settings_view.dart lib/core/widgets/resource_list/resource_list_view.dart lib/shared/resources/models/resource_list_config.dart lib/composition/resources/resource_tag_options_provider.dart lib/features/actions/presentation/views/actions_list_view.dart lib/features/builds/presentation/views/builds_list_view.dart lib/features/procedures/presentation/views/procedures_list_view.dart lib/features/repos/presentation/views/repos_list_view.dart lib/features/syncs/presentation/views/syncs_list_view.dart
rtk git commit -m "refactor: invert core feature dependencies" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Add Architecture Guard Test

**Files:**
- Create: `test/architecture/dependency_rules_test.dart`

**Interfaces:**
- The test fails if `lib/shared` imports `lib/features`.
- The test fails if a feature imports a different feature directly.
- The test fails if `lib/core` imports a feature outside the explicit allow-list.
- The test allows composition-layer files to import features only when listed in the final allow-list.

- [ ] **Step 1: Create architecture test**

Create `test/architecture/dependency_rules_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _featureImportPrefix = 'package:komodo_go/features/';

const _compositionAllowList = {
  'lib/core/router/app_router.dart',
  'lib/composition/resources/resource_catalog_provider.dart',
  'lib/composition/resources/resource_name_resolver_provider.dart',
  'lib/composition/resources/resource_tag_options_provider.dart',
  'lib/composition/home/home_view.dart',
  'lib/composition/home/widgets/home_dashboard_tiles.dart',
  'lib/composition/resources/resources_view.dart',
  'lib/composition/stacks/stack_updates_provider.dart',
  'lib/composition/stacks/stack_updates_tab.dart',
  'lib/composition/alerters/alerter_detail_view.dart',
  'lib/composition/alerters/resource_targets_editor_sheet.dart',
  'lib/composition/builds/build_detail_view.dart',
  'lib/composition/builds/build_detail_sections.dart',
  'lib/composition/containers/containers_provider.dart',
  'lib/composition/containers/containers_view.dart',
  'lib/composition/deployments/deployment_detail_view.dart',
  'lib/composition/deployments/deployment_detail_sections.dart',
  'lib/composition/deployments/deployments_list_view.dart',
  'lib/composition/repos/repo_detail_view.dart',
  'lib/composition/repos/repo_detail_sections.dart',
  'lib/composition/settings/add_connection_sheet.dart',
  'lib/composition/settings/connections_view.dart',
  'lib/composition/settings/settings_view.dart',
  'lib/composition/stacks/stack_config_editor.dart',
  'lib/composition/stacks/stack_detail_view.dart',
  'lib/composition/stacks/stacks_list_view.dart',
  'lib/composition/syncs/sync_detail_view.dart',
  'lib/composition/syncs/sync_detail_sections.dart',
  'lib/composition/servers/servers_list_view.dart',
};

void main() {
  test('feature dependencies only flow through composition roots', () {
    final violations = <String>[];
    final libDir = Directory('lib');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart')) {
        continue;
      }

      final path = p.posix.normalize(entity.path.replaceAll(r'\', '/'));
      final importerFeature = _featureForPath(path);
      final isShared = path.startsWith('lib/shared/');
      final isCore = path.startsWith('lib/core/');
      final isComposition = path.startsWith('lib/composition/');
      final isAllowedComposition = _compositionAllowList.contains(path);

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final importedFeature = _importedFeature(lines[index]);
        if (importedFeature == null) continue;

        if (isShared) {
          violations.add('$path:${index + 1} shared imports $importedFeature');
          continue;
        }

        if (isCore && !isAllowedComposition) {
          violations.add('$path:${index + 1} core imports $importedFeature');
          continue;
        }

        if (importerFeature != null && importerFeature != importedFeature) {
          violations.add(
            '$path:${index + 1} $importerFeature imports $importedFeature',
          );
          continue;
        }

        if (isComposition && !isAllowedComposition) {
          violations.add(
            '$path:${index + 1} composition file missing allow-list entry',
          );
          continue;
        }

        if (importerFeature == null && !isCore && !isComposition) {
          violations.add(
            '$path:${index + 1} root/importer file imports $importedFeature',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

String? _featureForPath(String path) {
  final match = RegExp(r'^lib/features/([^/]+)/').firstMatch(path);
  return match?.group(1);
}

String? _importedFeature(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('import ')) return null;
  final markerIndex = trimmed.indexOf(_featureImportPrefix);
  if (markerIndex == -1) return null;
  final start = markerIndex + _featureImportPrefix.length;
  final slash = trimmed.indexOf('/', start);
  if (slash == -1) return null;
  return trimmed.substring(start, slash);
}
```

- [ ] **Step 2: Run guard test**

Run:

```bash
rtk fvm flutter test test/architecture/dependency_rules_test.dart
```

Expected: PASS. If it fails, do not relax the rules; move or invert the reported import.

- [ ] **Step 3: Run final dependency measurement**

Run:

```bash
rtk rg -n "package:komodo_go/features/" lib -g '!*.g.dart' -g '!*.freezed.dart'
```

Expected: every remaining feature import is in one of the allow-listed files above, and no line from `lib/shared/` appears.

- [ ] **Step 4: Full verification**

Run:

```bash
rtk fvm flutter analyze
rtk fvm flutter test
```

Expected: analyzer reports `No issues found!`; full test suite passes.

- [ ] **Step 5: Commit**

```bash
rtk git add test/architecture/dependency_rules_test.dart
rtk git commit -m "test: guard feature dependency boundaries" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
