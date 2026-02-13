import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/data/models/core_info.dart';
import 'package:komodo_go/core/providers/core_info_provider.dart';
import 'package:komodo_go/core/router/shell_state_provider.dart';
import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/providers/stack_updates_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:komodo_go/features/providers/data/models/docker_registry_account.dart';
import 'package:komodo_go/features/providers/presentation/providers/docker_registry_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/stacks/presentation/views/stack_detail_view.dart';
import 'package:komodo_go/features/stacks/presentation/views/stacks_list_view.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestStacks extends Stacks {
  _TestStacks(this._stacks);

  final List<StackListItem> _stacks;

  @override
  Future<List<StackListItem>> build() async => _stacks;
}

class _TestStackUpdates extends StackUpdates {
  _TestStackUpdates(this._state);

  final UpdatesState _state;

  @override
  Future<UpdatesState> build(String stackId) async => _state;
}

class _TestServers extends Servers {
  _TestServers(this._servers);

  final List<Server> _servers;

  @override
  Future<List<Server>> build() async => _servers;
}

class _TestRepos extends Repos {
  _TestRepos(this._repos);

  final List<RepoListItem> _repos;

  @override
  Future<List<RepoListItem>> build() async => _repos;
}

class _TestRegistries extends DockerRegistryAccounts {
  _TestRegistries(this._accounts);

  final List<DockerRegistryAccount> _accounts;

  @override
  Future<List<DockerRegistryAccount>> build() async => _accounts;
}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

class _TestShellIndex extends MainShellIndex {
  _TestShellIndex(this._index);

  final int _index;

  @override
  int build() => _index;
}

void main() {
  setUpAll(() async {
    await AppSyntaxHighlight.ensureInitialized();
  });

  testWidgets('Stacks list view shows stack cards', (
    WidgetTester tester,
  ) async {
    final stacks = [
      StackListItem.fromJson(<String, dynamic>{
        'id': 's1',
        'name': 'Stack One',
        'info': <String, dynamic>{
          'server_id': 'srv-1',
          'state': 'running',
          'services': <dynamic>[],
        },
      }),
    ];
    final servers = [
      Server.fromJson(<String, dynamic>{
        'id': 'srv-1',
        'name': 'Server One',
      }),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stacksProvider.overrideWith(() => _TestStacks(stacks)),
          serversProvider.overrideWith(() => _TestServers(servers)),
          tagsProvider.overrideWith(() => _TestTags(const [])),
        ],
        child: const MaterialApp(home: StacksListView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stack_card_s1')), findsOneWidget);
    expect(find.text('Stack One'), findsOneWidget);
  });

  testWidgets('Stack detail view shows config section', (
    WidgetTester tester,
  ) async {
    final stack = KomodoStack.fromJson(<String, dynamic>{
      'id': 's1',
      'name': 'Stack One',
      'config': <String, dynamic>{},
      'info': <String, dynamic>{},
    });
    final stacks = [
      StackListItem.fromJson(<String, dynamic>{
        'id': 's1',
        'name': 'Stack One',
        'info': <String, dynamic>{
          'server_id': 'srv-1',
          'state': 'running',
          'services': <dynamic>[],
        },
      }),
    ];
    final servers = [
      Server.fromJson(<String, dynamic>{
        'id': 'srv-1',
        'name': 'Server One',
      }),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mainShellIndexProvider.overrideWith(() => _TestShellIndex(1)),
          coreInfoProvider.overrideWith(
            (ref) async => const CoreInfo(webhookBaseUrl: ''),
          ),
          stacksProvider.overrideWith(() => _TestStacks(stacks)),
          stackDetailProvider.overrideWith((ref, id) async => stack),
          stackServicesProvider.overrideWith((ref, id) async => <StackService>[]),
          stackLogProvider.overrideWith((ref, id) async => null),
          stackUpdatesProvider.overrideWith2(
            (stackId) => _TestStackUpdates(
              const UpdatesState(items: <UpdateListItem>[], nextPage: null),
            ),
          ),
          serversProvider.overrideWith(() => _TestServers(servers)),
          reposProvider.overrideWith(() => _TestRepos(const [])),
          dockerRegistryAccountsProvider.overrideWith(
            () => _TestRegistries(const []),
          ),
          tagsProvider.overrideWith(() => _TestTags(const [])),
        ],
        child: const MaterialApp(
          home: StackDetailView(stackId: 's1', stackName: 'Stack One'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stack_tab_config')), findsOneWidget);
    // Check that the Server section is rendered in the config tab
    expect(find.text('Server'), findsWidgets);
  });
}
