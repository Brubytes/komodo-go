import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/composition/containers/containers_provider.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/presentation/widgets/container_card.dart';
import 'package:komodo_go/features/containers/presentation/widgets/container_card_parts.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/widgets/stack_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

StackListItem _stack({
  StackState state = StackState.running,
  bool update = false,
  String repo = '',
  String branch = '',
  List<String> tags = const [],
}) => StackListItem(
  id: 's1',
  name: 'media',
  tags: tags,
  info: StackListItemInfo(
    serverId: 'srv',
    state: state,
    repo: repo,
    branch: branch,
    services: [StackServiceWithUpdate(service: 'web', updateAvailable: update)],
  ),
);

ContainerOverviewItem _container(
  ContainerState state, {
  ContainerStats? stats,
}) => ContainerOverviewItem(
  serverId: 'srv',
  serverName: 'Server One',
  container: ContainerListItem(
    id: 'c1',
    name: 'web',
    image: 'nginx:latest',
    state: state,
    networks: const ['bridge', 'proxy'],
    stats: stats,
  ),
);

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Actions'));
  await tester.pumpAndSettle();
}

void main() {
  group('StackCard', () {
    Future<void> pumpStack(
      WidgetTester tester,
      StackListItem stack, {
      List<StackAction>? actions,
      List<String> tags = const [],
    }) async {
      await tester.pumpWidget(
        _wrap(
          StackCard(
            stack: stack,
            serverName: 'Server One',
            displayTags: tags,
            onAction: (a) => actions?.add(a),
          ),
        ),
      );
    }

    testWidgets('running stack menu: lifecycle, maintenance, destroy last', (
      tester,
    ) async {
      await pumpStack(tester, _stack());
      await _openMenu(tester);

      for (final label in [
        'Restart',
        'Pause',
        'Stop',
        'Pull images',
        'Check for updates',
        'Deploy if changed',
        'Redeploy',
        'Destroy',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Start'), findsNothing);
      expect(find.text('LIFECYCLE'), findsOneWidget);
      expect(find.text('MAINTENANCE'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Restart')).dy,
        lessThan(tester.getTopLeft(find.text('Pull images')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Redeploy')).dy,
        lessThan(tester.getTopLeft(find.text('Destroy')).dy),
      );
    });

    testWidgets('stopped stack only offers Start in lifecycle', (tester) async {
      final actions = <StackAction>[];
      await pumpStack(
        tester,
        _stack(state: StackState.stopped),
        actions: actions,
      );
      await _openMenu(tester);

      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
      expect(find.text('Restart'), findsNothing);
      expect(find.text('Pause'), findsNothing);

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(actions, [StackAction.start]);
    });

    testWidgets('long press opens the same menu', (tester) async {
      await pumpStack(tester, _stack());
      await tester.longPress(find.text('media'));
      await tester.pumpAndSettle();

      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Destroy'), findsOneWidget);
    });

    testWidgets('update available is the status, tags capped at two', (
      tester,
    ) async {
      await pumpStack(
        tester,
        _stack(update: true, repo: 'org/repo', branch: 'main'),
        tags: ['a', 'b', 'c', 'd'],
      );

      expect(find.text('Update available'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('resource_card_accent')),
        findsOneWidget,
      );
      expect(find.text('org/repo · main'), findsOneWidget);
      expect(find.text('org/repo'), findsNothing);
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.text('c'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });

    test('state tones', () {
      expect(stackStatusSpec(_stack()).tone, PillTone.success);
      expect(
        stackStatusSpec(_stack(state: StackState.unhealthy)).tone,
        PillTone.alert,
      );
      expect(
        stackStatusSpec(_stack(state: StackState.dead)).tone,
        PillTone.alert,
      );
      expect(
        stackStatusSpec(_stack(state: StackState.restarting)).tone,
        PillTone.warning,
      );
      expect(
        stackStatusSpec(_stack(state: StackState.stopped)).tone,
        PillTone.neutral,
      );
    });
  });

  group('ContainerCard', () {
    Future<void> pumpContainer(
      WidgetTester tester,
      ContainerOverviewItem item, {
      List<ContainerAction>? actions,
    }) async {
      await tester.pumpWidget(
        _wrap(
          ContainerCard(
            item: item,
            onAction: (a) => actions?.add(a),
          ),
        ),
      );
    }

    testWidgets('running container menu', (tester) async {
      await pumpContainer(tester, _container(ContainerState.running));
      await _openMenu(tester);

      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(find.text('Unpause'), findsNothing);
      expect(find.text('Pull images'), findsNothing);
    });

    testWidgets('paused container offers Unpause but not Pause', (
      tester,
    ) async {
      await pumpContainer(tester, _container(ContainerState.paused));
      await _openMenu(tester);

      expect(find.text('Unpause'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Stop'), findsOneWidget);
    });

    testWidgets('exited container offers Start, not Stop', (tester) async {
      final actions = <ContainerAction>[];
      await pumpContainer(
        tester,
        _container(ContainerState.exited),
        actions: actions,
      );
      await _openMenu(tester);

      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(actions, [ContainerAction.remove]);
    });

    testWidgets('long press opens the menu', (tester) async {
      await pumpContainer(tester, _container(ContainerState.running));
      await tester.longPress(find.text('web'));
      await tester.pumpAndSettle();

      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('list card shows server, image and one CPU/memory line', (
      tester,
    ) async {
      await pumpContainer(
        tester,
        _container(
          ContainerState.running,
          stats: const ContainerStats(
            cpuPerc: '1.5%',
            memUsage: '10MiB / 1GiB',
            netIo: '1kB / 2kB',
          ),
        ),
      );

      expect(find.text('Server One'), findsOneWidget);
      expect(find.text('nginx:latest'), findsOneWidget);
      expect(find.text('CPU'), findsOneWidget);
      expect(find.text('1.5%'), findsOneWidget);
      expect(find.text('MEM'), findsOneWidget);
      expect(find.textContaining('10MiB/1GiB'), findsOneWidget);
      expect(find.text('↓ 1kB  ↑ 2kB'), findsOneWidget);
      expect(find.byType(ContainerMetricsGrid), findsOneWidget);
    });

    testWidgets('exited container hides metrics', (tester) async {
      await pumpContainer(
        tester,
        _container(
          ContainerState.exited,
          stats: const ContainerStats(cpuPerc: '1.5%'),
        ),
      );
      expect(find.byType(ContainerMetricsGrid), findsNothing);
    });

    test('formatContainerImage strips registry and library prefix', () {
      expect(
        formatContainerImage('docker.io/jlesage/jdownloader-2:latest'),
        'jlesage/jdownloader-2:latest',
      );
      expect(
        formatContainerImage('lscr.io/linuxserver/overseerr:latest'),
        'linuxserver/overseerr:latest',
      );
      expect(formatContainerImage('nginx'), 'nginx');
      expect(
        formatContainerImage('ghcr.io/komodo/billing:2.3.0'),
        'komodo/billing:2.3.0',
      );
      expect(formatContainerImage('docker.io/library/redis:7'), 'redis:7');
      expect(
        formatContainerImage('localhost:5000/app:1'),
        'app:1',
      );
    });

    test('formatContainerImage shortens hashes and keeps the name', () {
      expect(
        formatContainerImage(
          'gitea.tuna-carat.ts.net/madnex/familienarchiv-photo-manager:'
          'release-9d0b572dd234d14b9496c4c369a60501',
        ),
        'madnex/familienarchiv-photo-manager:release-9d0b…',
      );
      expect(
        formatContainerImage(
          'registry.example.com:5000/team/sub/app:'
          '0123456789abcdef0123456789abcdef',
        ),
        'team/sub/app:0123456789ab…',
      );
      expect(
        formatContainerImage(
          'docker:sha256:1f029db43a32aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        'docker@sha256:1f029db43a32',
      );
      expect(
        formatContainerImage(
          'docker.io/library/nginx@sha256:'
          '1f029db43a32bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
        'nginx@sha256:1f029db43a32',
      );
      expect(formatContainerImage('redis:7.2.4-alpine'), 'redis:7.2.4-alpine');
      expect(formatContainerImage(':release-abc'), isNotEmpty);
    });

    testWidgets('long image and name do not overflow at 360pt', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          const ContainerCard(
            item: ContainerOverviewItem(
              serverId: 'srv',
              serverName: 'a-really-long-server-name-for-the-home-lab',
              container: ContainerListItem(
                id: 'c1',
                name: 'familienarchiv-photo-manager-production-worker-instance',
                image:
                    'gitea.tuna-carat.ts.net/madnex/familienarchiv-photo-manager:'
                    'release-9d0b572dd234d14b9496c4c369a60501',
                state: ContainerState.running,
                networks: ['familienarchiv-internal-network', 'proxy'],
                ports: [
                  ContainerPort(privatePort: 8765, publicPort: 18765),
                  ContainerPort(privatePort: 80, publicPort: 8080),
                  ContainerPort(privatePort: 443, publicPort: 8443),
                  ContainerPort(privatePort: 22, publicPort: 2222),
                ],
                stats: ContainerStats(
                  cpuPerc: '1.5%',
                  memUsage: '10MiB / 1GiB',
                  memPerc: '1%',
                  netIo: '1kB / 2kB',
                  blockIo: '0B / 0B',
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('18765→8765'), findsOneWidget);
      expect(find.text('2222→22'), findsNothing);
    });
  });
}
