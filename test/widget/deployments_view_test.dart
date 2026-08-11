import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/deployments/deployment_detail_view.dart';
import 'package:komodo_go/composition/deployments/deployments_list_view.dart';
import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/providers/data/models/docker_registry_account.dart';
import 'package:komodo_go/features/providers/presentation/providers/docker_registry_provider.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestDeployments extends Deployments {
  _TestDeployments(this._deployments);

  final List<Deployment> _deployments;

  @override
  Future<List<Deployment>> build() async => _deployments;
}

class _TestServers extends Servers {
  _TestServers(this._servers);

  final List<Server> _servers;

  @override
  Future<List<Server>> build() async => _servers;
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

void main() {
  setUpAll(() async {
    await AppSyntaxHighlight.ensureInitialized();
  });

  testWidgets('Deployments list view shows deployment cards', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final deployments = [
      Deployment.fromJson(<String, dynamic>{
        'id': 'd1',
        'name': 'Deployment One',
        'info': <String, dynamic>{
          'state': 'running',
          'server_id': 'srv-1',
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
          deploymentsProvider.overrideWith(() => _TestDeployments(deployments)),
          serversProvider.overrideWith(() => _TestServers(servers)),
          tagsProvider.overrideWith(() => _TestTags(const [])),
        ],
        child: const MaterialApp(home: DeploymentsListView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('deployment_card_d1')), findsOneWidget);
    expect(find.text('Deployment One'), findsOneWidget);

    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('More actions'), findsOneWidget);
    expect(find.byTooltip('Filters'), findsNothing);
    expect(find.byTooltip('Create Deployment'), findsNothing);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('resource_filter_disclosure')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Create Deployment'), findsOneWidget);
    expect(find.text('Batch operations'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Deployment detail view shows config section', (tester) async {
    final deployment = Deployment.fromJson(<String, dynamic>{
      'id': 'd1',
      'name': 'Deployment One',
      'config': <String, dynamic>{
        'server_id': 'srv-1',
        'image': 'nginx:latest',
      },
      'info': <String, dynamic>{
        'state': 'running',
        'server_id': 'srv-1',
      },
    });
    final servers = [
      Server.fromJson(<String, dynamic>{
        'id': 'srv-1',
        'name': 'Server One',
      }),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deploymentDetailProvider.overrideWith((ref, id) async => deployment),
          serversProvider.overrideWith(() => _TestServers(servers)),
          dockerRegistryAccountsProvider.overrideWith(
            () => _TestRegistries(const []),
          ),
        ],
        child: const MaterialApp(
          home: DeploymentDetailView(
            deploymentId: 'd1',
            deploymentName: 'Deployment One',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Config'), findsOneWidget);
    expect(find.text('Image'), findsWidgets);
  });
}
