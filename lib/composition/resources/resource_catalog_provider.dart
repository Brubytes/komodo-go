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
      options.add(
        ResourceOption(ref: ResourceRef(kind: kind, id: id), name: name),
      );
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
  final serversAsync = ref.watch(serversProvider);
  final stacksAsync = ref.watch(stacksProvider);
  final deploymentsAsync = ref.watch(deploymentsProvider);
  final buildsAsync = ref.watch(buildsProvider);
  final reposAsync = ref.watch(reposProvider);
  final proceduresAsync = ref.watch(proceduresProvider);
  final actionsAsync = ref.watch(actionsProvider);
  final syncsAsync = ref.watch(syncsProvider);
  final buildersAsync = ref.watch(buildersProvider);
  final alertersAsync = ref.watch(alertersProvider);

  final asyncValues = [
    serversAsync,
    stacksAsync,
    deploymentsAsync,
    buildsAsync,
    reposAsync,
    proceduresAsync,
    actionsAsync,
    syncsAsync,
    buildersAsync,
    alertersAsync,
  ];

  final hasLoading = asyncValues.any((value) => value.isLoading);
  final firstError = asyncValues.where((value) => value.hasError).firstOrNull;
  if (firstError != null && !hasLoading) {
    return AsyncValue.error(
      firstError.error!,
      firstError.stackTrace ?? StackTrace.current,
    );
  }

  final options = resourceOptionsFromLists(
    servers: _asyncListOrEmpty(serversAsync),
    stacks: _asyncListOrEmpty(stacksAsync),
    deployments: _asyncListOrEmpty(deploymentsAsync),
    builds: _asyncListOrEmpty(buildsAsync),
    repos: _asyncListOrEmpty(reposAsync),
    procedures: _asyncListOrEmpty(proceduresAsync),
    actions: _asyncListOrEmpty(actionsAsync),
    syncs: _asyncListOrEmpty(syncsAsync),
    builders: _asyncListOrEmpty(buildersAsync),
    alerters: _asyncListOrEmpty(alertersAsync),
  );

  if (hasLoading) {
    return const AsyncValue<List<ResourceOption>>.loading()
        // ignore: invalid_use_of_internal_member, preserves previous option data during loading
        .copyWithPrevious(AsyncValue.data(options));
  }
  return AsyncValue.data(options);
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
