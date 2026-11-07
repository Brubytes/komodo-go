import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/features/actions/data/models/action.dart' as act;
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';
import 'package:komodo_go/features/alerters/data/repositories/alerter_repository.dart';
import 'package:komodo_go/features/builders/data/repositories/builder_repository.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/data/repositories/procedure_repository.dart';
import 'package:komodo_go/features/providers/data/repositories/docker_registry_repository.dart';
import 'package:komodo_go/features/providers/data/repositories/git_provider_repository.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/data/repositories/sync_repository.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/data/repositories/tag_repository.dart';
import 'package:komodo_go/features/variables/data/repositories/variable_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

/// Creates every resource type with EVERY config field populated with
/// non-default values (non-empty lists, nested objects, non-default enum
/// variants) and parses them through the app's repositories.
///
/// Rationale: empty lists/default configs hide wrong-shaped entries (see the
/// Komodo 2.x `additional_env_files` crash), so these fixtures deliberately
/// exercise every shape.
void registerPopulatedShapesContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
            'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group(
    'Populated shapes contract (real backend)',
    () {
      late KomodoApiClient client;
      late String prefix;
      final cleanup = <({String type, Map<String, dynamic> params})>[];

      // Ids / names of the created fixtures.
      late String serverId;
      late String tagId;
      late Map<String, String> ids;

      Future<Map<String, dynamic>> create(
        String createType,
        String deleteType,
        Map<String, dynamic> params, {
        String deleteKey = 'id',
      }) async {
        final response = await client.write(
          RpcRequest(type: createType, params: params),
        );
        final map = response as Map<String, dynamic>;
        cleanup.add((
          type: deleteType,
          params: <String, dynamic>{
            deleteKey: deleteKey == 'name'
                ? map['name'].toString()
                : readIdFromMap(map),
          },
        ));
        return map;
      }

      Future<String> createResource(
        String kind,
        String suffix,
        Map<String, dynamic> resourceConfig,
      ) async {
        final map = await create(
          'Create$kind',
          'Delete$kind',
          <String, dynamic>{
            'name': '$prefix$suffix',
            'config': resourceConfig,
          },
        );
        final id = readIdFromMap(map);
        ids['$kind:$suffix'] = id;
        await client.write(
          RpcRequest(
            type: 'UpdateResourceMeta',
            params: <String, dynamic>{
              'target': <String, dynamic>{'type': kind, 'id': id},
              'description': 'audit description $suffix',
              'tags': <String>[tagId],
            },
          ),
        );
        return id;
      }

      setUpAll(() async {
        final cfg = requireConfig(config);
        await resetBackendIfConfigured(cfg);
        client = buildTestClient(cfg, RpcRecorder());
        prefix = 'zz-audit-${_token(Random())}-';
        ids = <String, String>{};

        final tag = await create(
          'CreateTag',
          'DeleteTag',
          <String, dynamic>{'name': '${prefix}tag', 'color': 'DarkRose'},
        );
        tagId = readIdFromMap(tag);

        await create(
          'CreateVariable',
          'DeleteVariable',
          <String, dynamic>{
            'name': 'ZZ_AUDIT_${_token(Random()).toUpperCase()}',
            'value': 'secret-value',
            'description': 'audit variable',
            'is_secret': true,
          },
          deleteKey: 'name',
        );

        // Any pre-existing server (core's own) is used for targets that must
        // be connected; the audit server below is only used for config shapes.
        final servers = await client.read(
          const RpcRequest(type: 'ListServers', params: <String, dynamic>{}),
        );
        serverId = (servers as List)
            .cast<Map<String, dynamic>>()
            .first['id']
            .toString();

        await createResource('Builder', 'b-url', _urlBuilder);
        await createResource('Builder', 'b-server', <String, dynamic>{
          'type': 'Server',
          'params': <String, dynamic>{
            'server_ids': <String>[serverId],
          },
        });
        await createResource('Builder', 'b-aws', _awsBuilder);

        await createResource('Server', 'server', _serverConfig);

        final builderId = ids['Builder:b-server']!;
        await createResource(
          'Build',
          'build-ghcr',
          _buildConfig(builderId, <Map<String, dynamic>>[
            <String, dynamic>{
              'domain': 'ghcr.io',
              'account': 'acc',
              'organization': 'myorg',
            },
          ]),
        );
        await createResource(
          'Build',
          'build-multi',
          _buildConfig(builderId, <Map<String, dynamic>>[
            <String, dynamic>{'domain': 'docker.io', 'account': 'a2'},
            <String, dynamic>{
              'domain': 'reg.example.com',
              'account': 'a3',
              'organization': 'org2',
            },
          ]),
        );
        await createResource(
          'Build',
          'build-none',
          _buildConfig(builderId, <Map<String, dynamic>>[]),
        );

        await createResource('Repo', 'repo', _repoConfig(serverId, builderId));
        await createResource('Stack', 'stack', _stackConfig(serverId));

        await createResource(
          'Deployment',
          'dep-image',
          _deploymentConfig(
            serverId,
            image: <String, dynamic>{
              'type': 'Image',
              'params': <String, dynamic>{'image': 'nginx:1.27'},
            },
            restart: 'always',
            signal: 'SIGHUP',
          ),
        );
        await createResource(
          'Deployment',
          'dep-build',
          _deploymentConfig(
            serverId,
            image: <String, dynamic>{
              'type': 'Build',
              'params': <String, dynamic>{
                'build_id': ids['Build:build-ghcr'],
                'version': <String, dynamic>{
                  'major': 1,
                  'minor': 2,
                  'patch': 3,
                },
              },
            },
            restart: 'on-failure',
            signal: 'SIGINT',
          ),
        );
        await createResource(
          'Deployment',
          'dep-norestart',
          _deploymentConfig(
            serverId,
            image: <String, dynamic>{
              'type': 'Image',
              'params': <String, dynamic>{'image': 'busybox'},
            },
            restart: 'no',
            signal: 'SIGQUIT',
          ),
        );

        for (final type in <String>[
          'Custom',
          'Slack',
          'Discord',
          'Ntfy',
          'Pushover',
        ]) {
          await createResource(
            'Alerter',
            'al-${type.toLowerCase()}',
            _alerterConfig(type, serverId),
          );
        }

        await createResource('Action', 'action', _actionConfig);
        await createResource('ResourceSync', 'sync', _syncConfig(prefix));
        await createResource(
          'Procedure',
          'proc',
          _procedureConfig(prefix, ids),
        );

        await create(
          'CreateGitProviderAccount',
          'DeleteGitProviderAccount',
          <String, dynamic>{
            'account': <String, dynamic>{
              'domain': '${prefix}git.example.com',
              'https': false,
              'username': 'git-user',
              'token': 'git-token',
            },
          },
        );
        await create(
          'CreateDockerRegistryAccount',
          'DeleteDockerRegistryAccount',
          <String, dynamic>{
            'account': <String, dynamic>{
              'domain': '${prefix}reg.example.com',
              'username': 'reg-user',
              'token': 'reg-token',
            },
          },
        );
      });

      tearDownAll(() async {
        for (final entry in cleanup.reversed) {
          try {
            await client.write(
              RpcRequest(type: entry.type, params: entry.params),
            );
          } on Object catch (_) {
            // Best effort: never mask the test result with cleanup errors.
          }
        }
      });

      String id(String key) => ids[key]!;

      test('tags: color and owner', () async {
        final tags = expectRight(await TagRepository(client).listTags());
        final tag = tags.firstWhere((t) => t.id == tagId);
        expect(tag.name, '${prefix}tag');
        expect(tag.color, TagColor.darkRose);
        expect(tag.owner, isNotEmpty);
      });

      test('variables: secret flag and description', () async {
        final variables = expectRight(
          await VariableRepository(client).listVariables(),
        );
        final variable = variables.firstWhere(
          (v) => v.name.startsWith('ZZ_AUDIT_'),
        );
        expect(variable.isSecret, isTrue);
        expect(variable.description, 'audit variable');
        expect(variable.value, 'secret-value');
      });

      test('git provider and docker registry accounts', () async {
        final git = expectRight(
          await GitProviderRepository(client).listAccounts(),
        );
        final gitAccount = git.firstWhere(
          (a) => a.domain == '${prefix}git.example.com',
        );
        expect(gitAccount.username, 'git-user');
        expect(gitAccount.https, isFalse);
        expect(gitAccount.token, 'git-token');
        expect(gitAccount.id, isNotEmpty);

        final docker = expectRight(
          await DockerRegistryRepository(client).listAccounts(),
        );
        final dockerAccount = docker.firstWhere(
          (a) => a.domain == '${prefix}reg.example.com',
        );
        expect(dockerAccount.username, 'reg-user');
        expect(dockerAccount.token, 'reg-token');
        expect(dockerAccount.id, isNotEmpty);
      });

      test('server: list + get with maintenance windows', () async {
        final repository = ServerRepository(client);
        final serverIdLocal = id('Server:server');

        final listItem = expectRight(
          await repository.listServers(),
        ).firstWhere((s) => s.id == serverIdLocal);
        expect(listItem.tags, contains(tagId));
        expect(listItem.address, 'https://periphery.example.com:8120');
        expect(listItem.info?.region, 'eu');
        expect(listItem.info?.sendCpuAlerts, isFalse);

        final server = expectRight(await repository.getServer(serverIdLocal));
        // GetServer's `info` has no address; it must fall back to config.
        expect(server.address, 'https://periphery.example.com:8120');
        final cfg = server.config!;
        expect(cfg.externalAddress, 'ext.example.com');
        expect(cfg.region, 'eu');
        expect(cfg.enabled, isFalse);
        expect(cfg.passkey, 'pass');
        expect(cfg.ignoreMounts, <String>['/mnt/a', '/mnt/b']);
        expect(cfg.links, <String>['https://example.com']);
        expect(cfg.statsMonitoring, isFalse);
        expect(cfg.sendUnreachableAlerts, isFalse);
        expect(cfg.sendCpuAlerts, isFalse);
        expect(cfg.sendMemAlerts, isFalse);
        expect(cfg.sendDiskAlerts, isFalse);
        expect(cfg.sendVersionMismatchAlerts, isFalse);
        expect(cfg.cpuWarning, 55);
        expect(cfg.cpuCritical, 77);
        expect(cfg.memWarning, 60);
        expect(cfg.memCritical, 80);
        expect(cfg.diskWarning, 65);
        expect(cfg.diskCritical, 85);
        expect(
          cfg.maintenanceWindows.map((w) => w.scheduleType),
          <MaintenanceScheduleType>[
            MaintenanceScheduleType.daily,
            MaintenanceScheduleType.weekly,
            MaintenanceScheduleType.oneTime,
          ],
        );
        final weekly = cfg.maintenanceWindows[1];
        expect(weekly.dayOfWeek, 'Monday');
        expect(weekly.enabled, isFalse);
        expect(weekly.durationMinutes, 45);
        final once = cfg.maintenanceWindows[2];
        expect(once.date, '2030-01-02');
        expect(once.hour, 5);
        expect(once.timezone, 'UTC');

        // Write round-trip of the editor's maintenance window format.
        final updated = expectRight(
          await repository.updateServerConfig(
            serverId: serverIdLocal,
            partialConfig: <String, dynamic>{
              'maintenance_windows': [
                for (final w in cfg.maintenanceWindows.reversed) w.toJson(),
              ],
            },
          ),
        );
        expect(
          updated.config!.maintenanceWindows.map((w) => w.name),
          <String>['once', 'weekly', 'daily'],
        );
      });

      test('server list item exposes access flags and state', () async {
        final servers = expectRight(
          await ServerRepository(client).listServers(),
        );
        // The core's own server is the only one that is actually reachable.
        final reachable = servers.firstWhere(
          (s) => s.id == serverId,
          orElse: () => servers.first,
        );
        expect(reachable.info, isNotNull);
        expect(reachable.info!.state, isNot(ServerState.unknown));
        final audit = servers.firstWhere((s) => s.id == id('Server:server'));
        expect(audit.state, ServerState.disabled);
      });

      test('stack: full config incl. additional_env_files + config_files', () async {
        final repository = StackRepository(client);
        final stackId = id('Stack:stack');

        final listItem = expectRight(
          await repository.listStacks(),
        ).firstWhere((s) => s.id == stackId);
        expect(listItem.name, '${prefix}stack');
        expect(listItem.tags, contains(tagId));
        expect(listItem.info.branch, 'dev');
        expect(listItem.info.repo, 'org/repo');
        expect(listItem.info.gitProvider, 'git.example.com');

        final stack = expectRight(await repository.getStack(stackId));
        expect(stack.description, 'audit description stack');
        final c = stack.config;
        expect(c.serverId, serverId);
        expect(c.links, <String>['https://s.example.com']);
        expect(c.projectName, 'zzproj');
        expect(c.autoPull, isFalse);
        expect(c.runBuild, isTrue);
        expect(c.destroyBeforeDeploy, isTrue);
        expect(c.pollForUpdates, isTrue);
        expect(c.autoUpdate, isTrue);
        expect(c.sendAlerts, isFalse);
        expect(c.repo, 'org/repo');
        expect(c.branch, 'dev');
        expect(c.commit, 'abc');
        expect(c.clonePath, '/opt/c');
        expect(c.reclone, isTrue);
        expect(c.runDirectory, 'sub');
        expect(c.webhookEnabled, isTrue);
        expect(c.webhookForceDeploy, isTrue);
        expect(c.webhookSecret, 'ws');
        expect(c.filePaths, <String>['a.yaml', 'b.yaml']);
        expect(c.envFilePath, '.env');
        expect(
          c.additionalEnvFiles
              .map((f) => (path: f.path, track: f.track))
              .toList(),
          [(path: '.env.a', track: true), (path: '.env.b', track: false)],
        );
        expect(c.configFiles.map((f) => f.path), <String>[
          'conf/a.conf',
          'conf/b.conf',
          'conf/c.conf',
        ]);
        expect(c.configFiles[0].services, <String>['web', 'db']);
        expect(c.configFiles[0].requires, StackFileRequires.redeploy);
        expect(c.configFiles[1].services, isEmpty);
        expect(c.configFiles[1].requires, StackFileRequires.restart);
        expect(c.configFiles[2].requires, StackFileRequires.none);
        expect(c.ignoreServices, <String>['db']);
        expect(c.registryProvider, 'ghcr.io');
        expect(c.registryAccount, 'acc');
        expect(c.extraArgs, <String>['--pull', 'always']);
        expect(c.buildExtraArgs, <String>['--no-cache']);
        expect(c.fileContents, contains('image: nginx'));
        expect(c.environment, 'K=V\n');

        // Editor write format round-trips (2.x object shape + legacy strings).
        final written = expectRight(
          await repository.updateStackConfig(
            stackId: stackId,
            partialConfig: <String, dynamic>{
              'additional_env_files': stackAdditionalEnvFilesToJson(const [
                StackAdditionalEnvFile(path: '.new', track: false),
              ]),
              'config_files': <Map<String, dynamic>>[
                <String, dynamic>{
                  'path': 'x.conf',
                  'services': <String>['a'],
                  'requires': 'Restart',
                },
              ],
            },
          ),
        );
        expect(written.config.additionalEnvFiles.single.path, '.new');
        expect(written.config.additionalEnvFiles.single.track, isFalse);
        expect(
          written.config.configFiles.single.requires,
          StackFileRequires.restart,
        );
        final legacy = expectRight(
          await repository.updateStackConfig(
            stackId: stackId,
            partialConfig: <String, dynamic>{
              'additional_env_files': <String>['.legacy'],
            },
          ),
        );
        expect(legacy.config.additionalEnvFiles.single.path, '.legacy');
      });

      test('deployments: image vs build source, restart modes', () async {
        final repository = DeploymentRepository(client);
        final list = expectRight(await repository.listDeployments());
        final byId = {for (final d in list) d.id: d};

        final image = expectRight(
          await repository.getDeployment(id('Deployment:dep-image')),
        );
        expect(byId[image.id], isNotNull, reason: 'listed (not skipped)');
        expect(image.imageLabel, 'nginx:1.27');
        final ic = image.config!;
        expect(ic.customName, 'zzcustom');
        expect(ic.imageRegistryAccount, 'acc');
        expect(ic.skipSecretInterp, isTrue);
        expect(ic.redeployOnBuild, isTrue);
        expect(ic.pollForUpdates, isTrue);
        expect(ic.autoUpdate, isTrue);
        expect(ic.sendAlerts, isFalse);
        expect(ic.links, <String>['https://d.example.com']);
        expect(ic.network, 'host');
        expect(ic.restart, 'always');
        expect(ic.command, '--flag');
        expect(ic.terminationSignal, 'SIGHUP');
        expect(ic.terminationTimeout, 33);
        expect(ic.extraArgs, <String>['--cpus=1', '--memory=1g']);
        expect(ic.termSignalLabels, 'SIGTERM=graceful\n');
        expect(ic.ports, '8080:80\n');
        expect(ic.volumes, '/a:/b\n');
        expect(ic.environment, 'E=1\n');
        expect(ic.labels, 'l=1\n');

        final build = expectRight(
          await repository.getDeployment(id('Deployment:dep-build')),
        );
        expect(build.config!.restart, 'on-failure');
        expect(build.config!.terminationSignal, 'SIGINT');
        expect(build.config!.image, isA<Map<dynamic, dynamic>>());
        expect((build.config!.image as Map)['type'], 'Build');
        expect(byId[build.id]?.info?.buildId, id('Build:build-ghcr'));

        final noRestart = expectRight(
          await repository.getDeployment(id('Deployment:dep-norestart')),
        );
        expect(noRestart.config!.restart, 'no');
        expect(noRestart.config!.terminationSignal, 'SIGQUIT');

        // The editor writes the image as a tagged object.
        final updated = expectRight(
          await repository.updateDeploymentConfig(
            deploymentId: image.id,
            partialConfig: <String, dynamic>{
              'image': <String, dynamic>{
                'type': 'Image',
                'image': 'nginx:1.28',
                'params': <String, dynamic>{'image': 'nginx:1.28'},
              },
              'restart': 'unless-stopped',
              'termination_signal': 'SIGTERM',
            },
          ),
        );
        expect(updated.imageLabel, 'nginx:1.28');
        expect(updated.config!.restart, 'unless-stopped');
      });

      test('builds: every image registry variant', () async {
        final repository = BuildRepository(client);
        final list = expectRight(await repository.listBuilds());
        for (final key in ['build-ghcr', 'build-multi', 'build-none']) {
          expect(list.any((b) => b.id == id('Build:$key')), isTrue);
        }
        final listed = list.firstWhere((b) => b.id == id('Build:build-ghcr'));
        expect(listed.info.imageRegistryDomain, 'ghcr.io');
        expect(listed.info.builderId, id('Builder:b-server'));

        final build = expectRight(
          await repository.getBuild(id('Build:build-ghcr')),
        );
        final c = build.config;
        expect(c.builderId, id('Builder:b-server'));
        expect(c.version.label, '1.2.3');
        expect(c.imageName, 'img');
        expect(c.imageTag, 'tag');
        expect(c.repo, 'org/repo');
        expect(c.branch, 'dev');
        expect(c.commit, 'abc123');
        expect(c.webhookEnabled, isTrue);
        expect(c.buildPath, './ctx');
        expect(c.dockerfilePath, 'docker/Dockerfile');
        expect(c.skipSecretInterp, isTrue);
        expect(c.useBuildx, isTrue);
        expect(c.extraArgs, <String>['--no-cache', '--pull']);
        expect(build.tags, contains(tagId));

        // Registry shapes are not modelled; assert the raw shape stays an
        // array of objects so a model addition would parse it.
        final raw = await client.read(
          RpcRequest(
            type: 'GetBuild',
            params: <String, dynamic>{'build': id('Build:build-multi')},
          ),
        );
        final registries =
            ((raw as Map<String, dynamic>)['config']
                    as Map<String, dynamic>)['image_registry']
                as List;
        expect(registries, hasLength(2));
        expect((registries[1] as Map)['organization'], 'org2');
        expect(
          expectRight(await repository.getBuild(id('Build:build-none'))).id,
          id('Build:build-none'),
        );
      });

      test('repo: full config', () async {
        final repository = RepoRepository(client);
        final listed = expectRight(
          await repository.listRepos(),
        ).firstWhere((r) => r.id == id('Repo:repo'));
        expect(listed.info.gitProvider, 'git.example.com');
        expect(listed.info.serverId, serverId);
        expect(listed.info.builderId, id('Builder:b-server'));
        final repo = expectRight(await repository.getRepo(id('Repo:repo')));
        final c = repo.config;
        expect(c.serverId, serverId);
        expect(c.gitProvider, 'git.example.com');
        expect(c.gitHttps, isFalse);
        expect(c.gitAccount, 'gacc');
        expect(c.repo, 'org/repo');
        expect(c.branch, 'dev');
        expect(c.commit, 'abc');
        expect(c.path, '/opt/repos/x');
        expect(c.webhookEnabled, isTrue);
        expect(c.skipSecretInterp, isTrue);
      });

      test('procedure: stages with many execution types', () async {
        final repository = ProcedureRepository(client);
        final listed = expectRight(
          await repository.listProcedures(),
        ).firstWhere((p) => p.id == id('Procedure:proc'));
        expect(listed.info.stages, 3);

        final proc = expectRight(
          await repository.getProcedure(id('Procedure:proc')),
        );
        final c = proc.config;
        expect(c.scheduleFormat, ScheduleFormat.english);
        expect(c.schedule, 'Every day at 03:00');
        expect(c.scheduleEnabled, isTrue);
        expect(c.scheduleTimezone, 'Europe/Berlin');
        expect(c.scheduleAlert, isTrue);
        expect(c.failureAlert, isTrue);
        expect(c.webhookEnabled, isTrue);
        expect(c.webhookSecret, 'ws');
        expect(c.stages.map((s) => s.name), <String>['s1', 's2', 'empty']);
        expect(c.stages.map((s) => s.enabled), <bool>[true, false, true]);
        expect(c.stages[2].executions, isEmpty);
        final types = [
          for (final s in c.stages)
            for (final e in s.executions)
              (e.execution as Map<String, dynamic>)['type'],
        ];
        expect(types, <String>[
          'RunBuild',
          'Deploy',
          'DeployStack',
          'Sleep',
          'RunAction',
          'PullRepo',
          'RunSync',
          'StartContainer',
          'PruneImages',
          'BackupCoreDatabase',
          'GlobalAutoUpdate',
          'None',
          'BatchDeploy',
          'TestAlerter',
        ]);
        expect(
          c.stages[0].executions.map((e) => e.enabled),
          <bool>[true, false, true, false, true, false, true],
        );
        // Targets are stored as ids, not names.
        final runBuild = c.stages[0].executions[0].execution as Map;
        expect((runBuild['params'] as Map)['build'], id('Build:build-ghcr'));

        final cron = expectRight(
          await repository.updateProcedureConfig(
            procedureId: proc.id,
            partialConfig: <String, dynamic>{'schedule_format': 'Cron'},
          ),
        );
        expect(cron.config.scheduleFormat, ScheduleFormat.cron);
      });

      test('action: arguments format written as snake_case', () async {
        final repository = ActionRepository(client);
        final listed = expectRight(
          await repository.listActions(),
        ).firstWhere((a) => a.id == id('Action:action'));
        expect(listed.info.nextScheduledRun, isNotNull);

        final action = expectRight(
          await repository.getAction(id('Action:action')),
        );
        final c = action.config;
        expect(c.runAtStartup, isTrue);
        expect(c.scheduleFormat, act.ScheduleFormat.cron);
        expect(c.schedule, '0 0 3 * * *');
        expect(c.scheduleEnabled, isTrue);
        expect(c.scheduleTimezone, 'Europe/Berlin');
        expect(c.scheduleAlert, isTrue);
        expect(c.failureAlert, isTrue);
        expect(c.webhookEnabled, isTrue);
        expect(c.webhookSecret, 'ws');
        expect(c.reloadDenoDeps, isTrue);
        expect(c.fileContents, contains('console.log'));
        expect(c.argumentsFormat, act.FileFormat.yaml);
        expect(c.arguments, 'a: 1\n');

        for (final format in act.FileFormat.values) {
          final updated = expectRight(
            await repository.updateActionConfig(
              actionId: action.id,
              partialConfig: <String, dynamic>{
                'arguments_format': format.apiValue,
              },
            ),
          );
          expect(updated.config.argumentsFormat, format);
        }
      });

      test('sync: config + pending diff shapes', () async {
        final repository = SyncRepository(client);
        final syncId = id('ResourceSync:sync');
        final listed = expectRight(
          await repository.listSyncs(),
        ).firstWhere((s) => s.id == syncId);
        expect(listed.info.managed, isFalse);

        final sync = expectRight(await repository.getSync(syncId));
        final c = sync.config;
        expect(c.gitProvider, 'git.example.com');
        expect(c.gitHttps, isFalse);
        expect(c.gitAccount, 'gacc');
        expect(c.branch, 'dev');
        expect(c.commit, 'abc');
        expect(c.webhookEnabled, isTrue);
        expect(c.webhookSecret, 'ws');
        expect(c.resourcePath, <String>['stacks', 'deploy/a.toml']);
        expect(c.managed, isFalse);
        expect(c.delete, isTrue);
        expect(c.includeResources, isTrue);
        expect(c.matchTags, <String>['${prefix}tag']);
        expect(c.includeVariables, isTrue);
        expect(c.includeUserGroups, isTrue);
        expect(c.pendingAlert, isFalse);
        expect(c.fileContents, contains('[[stack]]'));

        // Switch to UI-defined contents so a refresh computes real diffs
        // (create / update / delete, variables, user groups).
        expectRight(
          await repository.updateSyncConfig(
            syncId: syncId,
            partialConfig: <String, dynamic>{
              'repo': '',
              'git_account': '',
              'resource_path': <String>[],
              'match_tags': <String>[],
              'file_contents': _syncContents(prefix),
            },
          ),
        );
        final refreshed = expectRight(await repository.refreshPending(syncId));
        final info = refreshed.info;
        expect(info.pendingError, isNull);
        expect(info.remoteContents, isNotEmpty);

        final creates = info.resourceUpdates.where(
          (u) => u.data.operation == SyncDiffOperation.create,
        );
        expect(
          creates.map((u) => u.name),
          contains('${prefix}sync-stack'),
        );
        final updates = info.resourceUpdates.where(
          (u) => u.data.operation == SyncDiffOperation.update,
        );
        // Update diffs carry no explicit name; it is read from the TOML.
        expect(updates.map((u) => u.name), contains('${prefix}dep-image'));
        final deletes = info.resourceUpdates.where(
          (u) => u.data.operation == SyncDiffOperation.delete,
        );
        expect(deletes, isNotEmpty);
        expect(deletes.every((u) => u.name.isNotEmpty), isTrue);
        expect(
          info.variableUpdates.map((u) => u.name),
          contains('ZZ_AUDIT_SYNC_VAR'),
        );
        expect(
          info.userGroupUpdates.map((u) => u.name),
          contains('${prefix}group'),
        );
      });

      test('builders: Url, Server and Aws list items + raw config', () async {
        final repository = BuilderRepository(client);
        final list = expectRight(await repository.listBuilders());
        final byId = {for (final b in list) b.id: b};
        expect(byId[id('Builder:b-url')]?.info.builderType, 'Url');
        expect(byId[id('Builder:b-server')]?.info.builderType, 'Server');
        expect(byId[id('Builder:b-aws')]?.info.builderType, 'Aws');
        expect(byId[id('Builder:b-aws')]?.info.instanceType, 't3.small');

        // The editor consumes the raw tagged `{type, params}` shape.
        final url = expectRight(
          await repository.getBuilderJson(
            builderIdOrName: id('Builder:b-url'),
          ),
        );
        final urlConfig = url['config'] as Map<String, dynamic>;
        expect(urlConfig['type'], 'Url');
        expect(
          (urlConfig['params'] as Map)['address'],
          'https://builder.example.com:8120',
        );
        final server = expectRight(
          await repository.getBuilderJson(
            builderIdOrName: id('Builder:b-server'),
          ),
        );
        expect(
          ((server['config'] as Map)['params'] as Map)['server_ids'],
          <String>[serverId],
        );
        final aws = expectRight(
          await repository.getBuilderJson(
            builderIdOrName: id('Builder:b-aws'),
          ),
        );
        final awsParams = (aws['config'] as Map)['params'] as Map;
        expect(awsParams['security_group_ids'], <String>['sg-1', 'sg-2']);
        expect(awsParams['volume_gb'], 30);
        expect(awsParams['image_registries'], hasLength(1));

        // Editor write format: tagged `{type, params}` update.
        expectRight(
          await repository.updateBuilderConfig(
            id: id('Builder:b-url'),
            config: <String, dynamic>{
              'type': 'Url',
              'params': <String, dynamic>{
                'address': 'https://changed.example.com:8120',
                'passkey': 'new',
              },
            },
          ),
        );
        final after = expectRight(
          await repository.getBuilderJson(
            builderIdOrName: id('Builder:b-url'),
          ),
        );
        expect(
          (((after['config'] as Map)['params']) as Map)['address'],
          'https://changed.example.com:8120',
        );
      });

      test('alerters: every endpoint type + filters + windows', () async {
        final repository = AlerterRepository(client);
        final list = expectRight(await repository.listAlerters());
        final byId = {for (final a in list) a.id: a};

        for (final type in ['Custom', 'Slack', 'Discord', 'Ntfy', 'Pushover']) {
          final alerterId = id('Alerter:al-${type.toLowerCase()}');
          expect(byId[alerterId]?.info.endpointType, type);
          expect(byId[alerterId]?.info.enabled, isTrue);

          final detail = expectRight(
            await repository.getAlerterDetail(alerterIdOrName: alerterId),
          );
          expect(detail.id, alerterId);
          expect(detail.name, '${prefix}al-${type.toLowerCase()}');
          final c = detail.config;
          expect(c.enabled, isTrue);
          expect(c.endpoint?.type, type);
          expect(c.endpoint?.url, 'https://hooks.example.com/$type');
          expect(
            c.endpoint?.email,
            type == 'Ntfy' ? 'a@b.c' : isNull,
          );
          expect(c.alertTypes, <String>[
            'ServerUnreachable',
            'ServerCpu',
            'StackStateChange',
            'BuildFailed',
          ]);
          expect(c.resources.single.variant, 'Server');
          expect(c.resources.single.value, serverId);
          expect(c.exceptResources.single.variant, 'Stack');
          final window = c.maintenanceWindows.single;
          expect(window.scheduleType, 'Weekly');
          expect(window.dayOfWeek, 'Friday');
          expect(window.hour, 1);
          expect(window.minute, 2);
          expect(window.durationMinutes, 3);
        }

        // Editor write format: endpoint payload + maintenance window map.
        final ntfyId = id('Alerter:al-ntfy');
        final ntfy = expectRight(
          await repository.getAlerterDetail(alerterIdOrName: ntfyId),
        );
        expectRight(
          await repository.updateAlerterConfig(
            id: ntfyId,
            config: <String, dynamic>{
              'endpoint': ntfy.config.endpoint!.toApiPayload(),
              'resources': [
                for (final r in ntfy.config.resources) r.toJson(),
              ],
              'maintenance_windows': [
                for (final w in ntfy.config.maintenanceWindows) w.toApiMap(),
              ],
            },
          ),
        );
        final reread = expectRight(
          await repository.getAlerterDetail(alerterIdOrName: ntfyId),
        );
        expect(reread.config.endpoint?.email, 'a@b.c');
        expect(reread.config.maintenanceWindows.single.dayOfWeek, 'Friday');
      });
    },
    skip: missingConfigReason ?? config?.skipReason(),
  );
}

void main() => registerPopulatedShapesContractTests();

String _token(Random random) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List<String>.generate(
    6,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

const _urlBuilder = <String, dynamic>{
  'type': 'Url',
  'params': <String, dynamic>{
    'address': 'https://builder.example.com:8120',
    'periphery_public_key': 'MCowBQYDK2VuAyEAabc',
    'insecure_tls': true,
    'passkey': 'pk',
  },
};

const _awsBuilder = <String, dynamic>{
  'type': 'Aws',
  'params': <String, dynamic>{
    'region': 'eu-central-1',
    'instance_type': 't3.small',
    'volume_gb': 30,
    'ami_id': 'ami-123',
    'subnet_id': 'subnet-1',
    'key_pair_name': 'kp',
    'assign_public_ip': true,
    'use_public_ip': true,
    'security_group_ids': <String>['sg-1', 'sg-2'],
    'user_data': '#!/bin/sh',
    'port': 8120,
    'use_https': true,
    'periphery_public_key': 'k',
    'insecure_tls': true,
    'git_providers': <Map<String, dynamic>>[
      <String, dynamic>{
        'domain': 'git.example.com',
        'https': true,
        'accounts': <Map<String, dynamic>>[
          <String, dynamic>{'username': 'u', 'token': 't'},
        ],
      },
    ],
    'image_registries': <Map<String, dynamic>>[
      <String, dynamic>{
        'domain': 'reg.example.com',
        'accounts': <Map<String, dynamic>>[
          <String, dynamic>{'username': 'u', 'token': 't'},
        ],
        'organizations': <String>['org'],
      },
    ],
    'secrets': <String>['S1', 'S2'],
  },
};

const _serverConfig = <String, dynamic>{
  'address': 'https://periphery.example.com:8120',
  'insecure_tls': true,
  'external_address': 'ext.example.com',
  'region': 'eu',
  'enabled': false,
  'auto_rotate_keys': false,
  'passkey': 'pass',
  'ignore_mounts': <String>['/mnt/a', '/mnt/b'],
  'auto_prune': false,
  'links': <String>['https://example.com'],
  'stats_monitoring': false,
  'send_unreachable_alerts': false,
  'send_cpu_alerts': false,
  'send_mem_alerts': false,
  'send_disk_alerts': false,
  'send_version_mismatch_alerts': false,
  'cpu_warning': 55,
  'cpu_critical': 77,
  'mem_warning': 60,
  'mem_critical': 80,
  'disk_warning': 65,
  'disk_critical': 85,
  'maintenance_windows': <Map<String, dynamic>>[
    <String, dynamic>{
      'name': 'daily',
      'description': 'dd',
      'schedule_type': 'Daily',
      'hour': 3,
      'minute': 15,
      'duration_minutes': 30,
      'timezone': 'Europe/Berlin',
      'enabled': true,
    },
    <String, dynamic>{
      'name': 'weekly',
      'description': 'ww',
      'schedule_type': 'Weekly',
      'day_of_week': 'Monday',
      'hour': 4,
      'minute': 0,
      'duration_minutes': 45,
      'timezone': 'UTC',
      'enabled': false,
    },
    <String, dynamic>{
      'name': 'once',
      'description': 'oo',
      'schedule_type': 'OneTime',
      'date': '2030-01-02',
      'hour': 5,
      'minute': 5,
      'duration_minutes': 10,
      'timezone': 'UTC',
      'enabled': true,
    },
  ],
};

Map<String, dynamic> _buildConfig(
  String builderId,
  List<Map<String, dynamic>> registries,
) => <String, dynamic>{
  'builder_id': builderId,
  'version': <String, dynamic>{'major': 1, 'minor': 2, 'patch': 3},
  'auto_increment_version': false,
  'image_name': 'img',
  'image_tag': 'tag',
  'include_latest_tag': true,
  'include_version_tags': false,
  'include_commit_tag': true,
  'links': <String>['https://l.example.com'],
  'git_provider': 'git.example.com',
  'git_https': false,
  'git_account': 'gacc',
  'repo': 'org/repo',
  'branch': 'dev',
  'commit': 'abc123',
  'webhook_enabled': true,
  'webhook_secret': 'ws',
  'files_on_host': false,
  'build_path': './ctx',
  'dockerfile_path': 'docker/Dockerfile',
  'image_registry': registries,
  'skip_secret_interp': true,
  'use_buildx': true,
  'extra_args': <String>['--no-cache', '--pull'],
  'pre_build': <String, dynamic>{
    'path': './pre',
    'command': 'make prep',
    'shell_mode': true,
  },
  'dockerfile': 'FROM alpine\n',
  'build_args': 'A=1\nB=2\n',
  'secret_args': 'S=1\n',
  'labels': 'l=1\n',
};

Map<String, dynamic> _repoConfig(String serverId, String builderId) =>
    <String, dynamic>{
      'server_id': serverId,
      'builder_id': builderId,
      'git_provider': 'git.example.com',
      'git_https': false,
      'git_account': 'gacc',
      'repo': 'org/repo',
      'branch': 'dev',
      'commit': 'abc',
      'path': '/opt/repos/x',
      'webhook_enabled': true,
      'webhook_secret': 'ws',
      'on_clone': <String, dynamic>{
        'path': './',
        'command': 'echo clone',
        'shell_mode': true,
      },
      'on_pull': <String, dynamic>{
        'path': './p',
        'command': 'echo pull',
        'shell_mode': false,
      },
      'links': <String>['https://x.example.com'],
      'environment': 'A=1\n',
      'env_file_path': '.env2',
      'skip_secret_interp': true,
    };

Map<String, dynamic> _stackConfig(String serverId) => <String, dynamic>{
  'server_id': serverId,
  'links': <String>['https://s.example.com'],
  'project_name': 'zzproj',
  'auto_pull': false,
  'run_build': true,
  'poll_for_updates': true,
  'auto_update': true,
  'auto_update_all_services': true,
  'auto_update_skip_services': <String>['redis'],
  'destroy_before_deploy': true,
  'skip_secret_interp': true,
  'git_provider': 'git.example.com',
  'git_https': false,
  'git_account': 'gacc',
  'repo': 'org/repo',
  'branch': 'dev',
  'commit': 'abc',
  'clone_path': '/opt/c',
  'reclone': true,
  'webhook_enabled': true,
  'webhook_secret': 'ws',
  'webhook_force_deploy': true,
  'files_on_host': false,
  'run_directory': 'sub',
  'file_paths': <String>['a.yaml', 'b.yaml'],
  'env_file_path': '.env',
  'additional_env_files': <Map<String, dynamic>>[
    <String, dynamic>{'path': '.env.a', 'track': true},
    <String, dynamic>{'path': '.env.b', 'track': false},
  ],
  'config_files': <Map<String, dynamic>>[
    <String, dynamic>{
      'path': 'conf/a.conf',
      'services': <String>['web', 'db'],
      'requires': 'Redeploy',
    },
    <String, dynamic>{
      'path': 'conf/b.conf',
      'services': <String>[],
      'requires': 'Restart',
    },
    <String, dynamic>{
      'path': 'conf/c.conf',
      'services': <String>['x'],
      'requires': 'None',
    },
  ],
  'send_alerts': false,
  'registry_provider': 'ghcr.io',
  'registry_account': 'acc',
  'pre_deploy': <String, dynamic>{
    'path': './',
    'command': 'echo pre',
    'shell_mode': true,
  },
  'post_deploy': <String, dynamic>{
    'path': './',
    'command': 'echo post',
    'shell_mode': false,
  },
  'extra_args': <String>['--pull', 'always'],
  'build_extra_args': <String>['--no-cache'],
  'compose_cmd_wrapper': 'wrap [[COMPOSE_COMMAND]]',
  'compose_cmd_wrapper_include': <String>['up'],
  'ignore_services': <String>['db'],
  'file_contents': 'services:\n  web:\n    image: nginx\n',
  'environment': 'K=V\n',
};

Map<String, dynamic> _deploymentConfig(
  String serverId, {
  required Map<String, dynamic> image,
  required String restart,
  required String signal,
}) => <String, dynamic>{
  'server_id': serverId,
  'custom_name': 'zzcustom',
  'image': image,
  'image_registry_account': 'acc',
  'skip_secret_interp': true,
  'redeploy_on_build': true,
  'poll_for_updates': true,
  'auto_update': true,
  'send_alerts': false,
  'links': <String>['https://d.example.com'],
  'network': 'host',
  'restart': restart,
  'command': '--flag',
  'replicas': 1,
  'termination_signal': signal,
  'termination_timeout': 33,
  'extra_args': <String>['--cpus=1', '--memory=1g'],
  'term_signal_labels': 'SIGTERM=graceful\n',
  'ports': '8080:80\n',
  'volumes': '/a:/b\n',
  'environment': 'E=1\n',
  'labels': 'l=1\n',
};

const _actionConfig = <String, dynamic>{
  'run_at_startup': true,
  'schedule_format': 'Cron',
  'schedule': '0 0 3 * * *',
  'schedule_enabled': true,
  'schedule_timezone': 'Europe/Berlin',
  'schedule_alert': true,
  'failure_alert': true,
  'webhook_enabled': true,
  'webhook_secret': 'ws',
  'reload_deno_deps': true,
  'file_contents': 'console.log(ARGS)',
  'arguments_format': 'yaml',
  'arguments': 'a: 1\n',
};

String _syncContents(String prefix) =>
    '''
[[stack]]
name = "${prefix}sync-stack"
[stack.config]
file_contents = "services: {}"

[[deployment]]
name = "${prefix}dep-image"
[deployment.config]
image.type = "Image"
image.params.image = "nginx:9"

[[variable]]
name = "ZZ_AUDIT_SYNC_VAR"
value = "1"

[[user_group]]
name = "${prefix}group"
everyone = false
''';

Map<String, dynamic> _syncConfig(String prefix) => <String, dynamic>{
  'git_provider': 'git.example.com',
  'git_https': false,
  'repo': 'org/repo',
  'branch': 'dev',
  'commit': 'abc',
  'git_account': 'gacc',
  'webhook_enabled': true,
  'webhook_secret': 'ws',
  'files_on_host': false,
  'resource_path': <String>['stacks', 'deploy/a.toml'],
  'managed': false,
  'delete': true,
  'include_resources': true,
  'match_tags': <String>['${prefix}tag'],
  'include_variables': true,
  'include_user_groups': true,
  'pending_alert': false,
  'file_contents': '[[stack]]\nname = "x"\n',
};

Map<String, dynamic> _procedureConfig(
  String prefix,
  Map<String, String> ids,
) {
  Map<String, dynamic> exec(String type, Map<String, dynamic> params) =>
      <String, dynamic>{'type': type, 'params': params};
  List<Map<String, dynamic>> wrap(
    List<Map<String, dynamic>> executions, {
    bool alternate = false,
  }) => [
    for (var i = 0; i < executions.length; i++)
      <String, dynamic>{
        'execution': executions[i],
        'enabled': !alternate || i.isEven,
      },
  ];

  return <String, dynamic>{
    'schedule_format': 'English',
    'schedule': 'Every day at 03:00',
    'schedule_enabled': true,
    'schedule_timezone': 'Europe/Berlin',
    'schedule_alert': true,
    'failure_alert': true,
    'webhook_enabled': true,
    'webhook_secret': 'ws',
    'stages': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 's1',
        'enabled': true,
        'executions': wrap(<Map<String, dynamic>>[
          exec('RunBuild', {'build': '${prefix}build-ghcr'}),
          exec('Deploy', {
            'deployment': '${prefix}dep-image',
            'stop_signal': 'SIGTERM',
            'stop_time': 5,
          }),
          exec('DeployStack', {
            'stack': '${prefix}stack',
            'services': <String>['web'],
          }),
          exec('Sleep', {'duration_ms': 100}),
          exec('RunAction', {
            'action': '${prefix}action',
            'args': {'a': 1},
          }),
          exec('PullRepo', {'repo': '${prefix}repo'}),
          exec('RunSync', {'sync': '${prefix}sync'}),
        ], alternate: true),
      },
      <String, dynamic>{
        'name': 's2',
        'enabled': false,
        'executions': wrap(<Map<String, dynamic>>[
          exec('StartContainer', {
            'server': '${prefix}server',
            'container': 'c',
          }),
          exec('PruneImages', {'server': '${prefix}server'}),
          exec('BackupCoreDatabase', {}),
          exec('GlobalAutoUpdate', {}),
          exec('None', {}),
          exec('BatchDeploy', {'pattern': 'zz-*'}),
          exec('TestAlerter', {'alerter': '${prefix}al-slack'}),
        ]),
      },
      <String, dynamic>{
        'name': 'empty',
        'enabled': true,
        'executions': <Map<String, dynamic>>[],
      },
    ],
  };
}

Map<String, dynamic> _alerterConfig(String type, String serverId) =>
    <String, dynamic>{
      'enabled': true,
      'endpoint': <String, dynamic>{
        'type': type,
        'params': <String, dynamic>{
          'url': 'https://hooks.example.com/$type',
          if (type == 'Ntfy') 'email': 'a@b.c',
        },
      },
      'alert_types': <String>[
        'ServerUnreachable',
        'ServerCpu',
        'StackStateChange',
        'BuildFailed',
      ],
      'resources': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'Server', 'id': serverId},
      ],
      'except_resources': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'Stack', 'id': 'excluded'},
      ],
      'maintenance_windows': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'mw',
          'description': 'd',
          'schedule_type': 'Weekly',
          'day_of_week': 'Friday',
          'hour': 1,
          'minute': 2,
          'duration_minutes': 3,
          'timezone': 'UTC',
          'enabled': true,
        },
      ],
    };
