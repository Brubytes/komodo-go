import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

final List<Map<String, dynamic>> _servers = [
  _serverItem(
    id: 'server-1',
    name: 'Primary Node',
    address: '10.0.0.10',
    region: 'us-east-1',
    state: 'Ok',
  ),
  _serverItem(
    id: 'server-2',
    name: 'Edge Node',
    address: '10.0.0.22',
    region: 'eu-west-1',
    state: 'Ok',
  ),
  _serverItem(
    id: 'server-3',
    name: 'Staging Node',
    address: '10.0.1.12',
    region: 'us-west-2',
    state: 'NotOk',
  ),
  _serverItem(
    id: 'server-4',
    name: 'DR Node',
    address: '10.0.2.5',
    region: 'ap-southeast-1',
    state: 'Disabled',
  ),
];

final List<Map<String, dynamic>> _deployments = [
  _deployment(
    id: 'deployment-1',
    name: 'Frontend',
    description: 'Public web entrypoint',
    state: 'Running',
    image: 'nginx:latest',
    serverId: 'server-1',
  ),
  _deployment(
    id: 'deployment-2',
    name: 'API',
    description: 'Core API service',
    state: 'Running',
    image: 'ghcr.io/komodo/api:1.2.3',
    serverId: 'server-1',
  ),
  _deployment(
    id: 'deployment-3',
    name: 'Worker',
    description: 'Background jobs',
    state: 'Paused',
    image: 'ghcr.io/komodo/worker:2.0.1',
    serverId: 'server-2',
  ),
  _deployment(
    id: 'deployment-4',
    name: 'Billing',
    description: 'Invoice pipeline',
    state: 'Exited',
    image: 'ghcr.io/komodo/billing:2.3.0',
    serverId: 'server-3',
  ),
  _deployment(
    id: 'deployment-5',
    name: 'Docs',
    description: 'Documentation site',
    state: 'not_deployed',
    image: 'nginx:alpine',
    serverId: 'server-4',
  ),
  _deployment(
    id: 'deployment-6',
    name: 'Metrics',
    description: 'Observability stack',
    state: 'Restarting',
    image: 'grafana/grafana:10.2.2',
    serverId: 'server-2',
  ),
];

const String _demoUiStackComposeFallbackYml = '''# Demo compose.yml (fallback)
# If you see this, the asset load failed.

services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
''';

String _demoUiStackComposeYml = _demoUiStackComposeFallbackYml;

final List<Map<String, dynamic>> _stacks = [
  _stackListItem(
    id: 'stack-demo-ui',
    name: 'Demo Stack',
    serverId: 'server-1',
    repo: '',
    branch: '',
    state: 'Running',
    fileContents: true,
    gitProvider: '',
    linkedRepo: '',
  ),
  _stackListItem(
    id: 'stack-1',
    name: 'Production Stack',
    serverId: 'server-1',
    repo: 'komodo/production-stack',
    branch: 'main',
    state: 'Running',
  ),
  _stackListItem(
    id: 'stack-2',
    name: 'Staging Stack',
    serverId: 'server-3',
    repo: 'komodo/staging-stack',
    branch: 'develop',
    state: 'Deploying',
  ),
  _stackListItem(
    id: 'stack-3',
    name: 'Edge Stack',
    serverId: 'server-2',
    repo: 'komodo/edge-stack',
    branch: 'main',
    state: 'Paused',
  ),
  _stackListItem(
    id: 'stack-4',
    name: 'Sandbox Stack',
    serverId: 'server-4',
    repo: 'komodo/sandbox-stack',
    branch: 'experiment',
    state: 'Stopped',
  ),
];

final List<Map<String, dynamic>> _repos = [
  _repoListItem(
    id: 'repo-1',
    name: 'Komodo API',
    serverId: 'server-1',
    builderId: 'builder-1',
    repo: 'komodo/api',
    branch: 'main',
    state: 'Ok',
  ),
  _repoListItem(
    id: 'repo-2',
    name: 'Komodo Web',
    serverId: 'server-2',
    builderId: 'builder-1',
    repo: 'komodo/web',
    branch: 'main',
    state: 'Pulling',
  ),
  _repoListItem(
    id: 'repo-3',
    name: 'Ops Config',
    serverId: 'server-3',
    builderId: 'builder-1',
    repo: 'komodo/ops-config',
    branch: 'main',
    state: 'Failed',
  ),
  _repoListItem(
    id: 'repo-4',
    name: 'Billing Service',
    serverId: 'server-3',
    builderId: 'builder-1',
    repo: 'komodo/billing',
    branch: 'release',
    state: 'Building',
  ),
];

final List<Map<String, dynamic>> _builds = [
  _buildListItem(
    id: 'build-1',
    name: 'API Image',
    builderId: 'builder-1',
    repo: 'komodo/api',
    branch: 'main',
    state: 'Ok',
  ),
  _buildListItem(
    id: 'build-2',
    name: 'Web Image',
    builderId: 'builder-1',
    repo: 'komodo/web',
    branch: 'main',
    state: 'Building',
  ),
  _buildListItem(
    id: 'build-3',
    name: 'Billing Image',
    builderId: 'builder-1',
    repo: 'komodo/billing',
    branch: 'release',
    state: 'Failed',
  ),
];

final List<Map<String, dynamic>> _syncs = [
  _syncListItem(
    id: 'sync-1',
    name: 'Resource Sync',
    repo: 'komodo/ops-config',
    branch: 'main',
    state: 'Ok',
  ),
  _syncListItem(
    id: 'sync-2',
    name: 'Staging Sync',
    repo: 'komodo/staging-stack',
    branch: 'develop',
    state: 'Syncing',
  ),
  _syncListItem(
    id: 'sync-3',
    name: 'Edge Config',
    repo: 'komodo/edge-stack',
    branch: 'main',
    state: 'Failed',
  ),
  _syncListItem(
    id: 'sync-4',
    name: 'Sandbox Sync',
    repo: 'komodo/sandbox-stack',
    branch: 'experiment',
    state: 'Pending',
  ),
];

final List<Map<String, dynamic>> _procedures = [
  _procedureListItem(
    id: 'procedure-1',
    name: 'Nightly Cleanup',
    stages: 3,
    state: 'Ok',
  ),
  _procedureListItem(
    id: 'procedure-2',
    name: 'Rotate Secrets',
    stages: 5,
    state: 'Running',
  ),
  _procedureListItem(
    id: 'procedure-3',
    name: 'Incident Drill',
    stages: 2,
    state: 'Failed',
  ),
];

final List<Map<String, dynamic>> _actions = [
  _actionListItem(id: 'action-1', name: 'Restart Web', state: 'Ok'),
  _actionListItem(id: 'action-2', name: 'Flush Cache', state: 'Running'),
  _actionListItem(id: 'action-3', name: 'Rollback Release', state: 'Failed'),
];

final List<Map<String, dynamic>> _containers = [
  _containerListItem(
    serverId: 'server-1',
    name: 'frontend',
    image: 'nginx:latest',
    status: 'Up 2 hours',
    state: 'Running',
  ),
  _containerListItem(
    serverId: 'server-1',
    name: 'api',
    image: 'ghcr.io/komodo/api:1.2.3',
    status: 'Up 2 hours',
    state: 'Running',
  ),
  _containerListItem(
    serverId: 'server-2',
    name: 'worker',
    image: 'ghcr.io/komodo/worker:2.0.1',
    status: 'Up 10 minutes',
    state: 'Paused',
  ),
  _containerListItem(
    serverId: 'server-2',
    name: 'metrics',
    image: 'grafana/grafana:10.2.2',
    status: 'Restarting (3)',
    state: 'Restarting',
  ),
  _containerListItem(
    serverId: 'server-3',
    name: 'billing',
    image: 'ghcr.io/komodo/billing:2.3.0',
    status: 'Exited (1) 2 hours ago',
    state: 'Exited',
  ),
  _containerListItem(
    serverId: 'server-4',
    name: 'docs',
    image: 'nginx:alpine',
    status: 'Created',
    state: 'Created',
  ),
];

final List<Map<String, dynamic>> _tags = [
  _tag(id: 'tag-1', name: 'Production', colorToken: 'Emerald'),
  _tag(id: 'tag-2', name: 'Staging', colorToken: 'Blue'),
  _tag(id: 'tag-3', name: 'Experimental', colorToken: 'Purple'),
  _tag(id: 'tag-4', name: 'Incident', colorToken: 'Red'),
];

final List<Map<String, dynamic>> _variables = [
  _variable(
    id: 'var-1',
    name: 'REGION',
    description: 'Default region for deployments',
    value: 'us-east-1',
    isSecret: false,
  ),
  _variable(
    id: 'var-2',
    name: 'LOG_LEVEL',
    description: 'Default application log level',
    value: 'INFO',
    isSecret: false,
  ),
  _variable(
    id: 'var-3',
    name: 'BILLING_TOKEN',
    description: 'Billing service token',
    value: '••••••••',
    isSecret: true,
  ),
];

final List<Map<String, dynamic>> _gitProviderAccounts = [
  _gitProviderAccount(
    id: 'git-1',
    domain: 'github.com',
    username: 'demo',
    https: true,
    token: '••••••••',
  ),
  _gitProviderAccount(
    id: 'git-2',
    domain: 'gitlab.com',
    username: 'ops-bot',
    https: true,
    token: '••••••••',
  ),
  _gitProviderAccount(
    id: 'git-3',
    domain: 'git.example.com',
    username: 'build',
    https: false,
    token: '••••••••',
  ),
];

final List<Map<String, dynamic>> _dockerRegistryAccounts = [
  _dockerRegistryAccount(
    id: 'registry-1',
    domain: 'ghcr.io',
    username: 'demo',
    token: '••••••••',
  ),
  _dockerRegistryAccount(
    id: 'registry-2',
    domain: 'docker.io',
    username: 'demo-bot',
    token: '••••••••',
  ),
  _dockerRegistryAccount(
    id: 'registry-3',
    domain: 'registry.example.com',
    username: 'deploy',
    token: '••••••••',
  ),
];

final List<Map<String, dynamic>> _builders = [
  _builderListItem(
    id: 'builder-1',
    name: 'Default Builder',
    builderType: 'Url',
    instanceType: null,
    tags: ['Production'],
    config: <String, dynamic>{
      'Url': <String, dynamic>{
        'address': 'https://builders.example.com',
        'passkey': 'demo-passkey',
      },
    },
  ),
  _builderListItem(
    id: 'builder-2',
    name: 'Staging Builder',
    builderType: 'Server',
    instanceType: null,
    tags: ['Staging'],
    config: <String, dynamic>{
      'Server': <String, dynamic>{'server_id': 'server-3'},
    },
  ),
  _builderListItem(
    id: 'builder-3',
    name: 'AWS Build Pool',
    builderType: 'Aws',
    instanceType: 't3.medium',
    tags: ['Experimental'],
    config: <String, dynamic>{
      'Aws': <String, dynamic>{
        'region': 'us-east-1',
        'instance_type': 't3.medium',
        'volume_gb': 50,
        'port': 2376,
        'use_https': true,
        'assign_public_ip': true,
        'use_public_ip': false,
      },
    },
  ),
];

final List<Map<String, dynamic>> _alerters = [
  _alerterListItem(
    id: 'alerter-1',
    name: 'Ops Slack',
    enabled: true,
    endpointType: 'Slack',
    tags: ['Production'],
    config: <String, dynamic>{
      'enabled': true,
      'endpoint': <String, dynamic>{
        'type': 'Slack',
        'params': <String, dynamic>{
          'url': 'https://hooks.slack.com/services/demo/demo/demo',
        },
      },
      'alert_types': <String>['ServerUnreachable', 'BuildFailed'],
      'resources': <Map<String, dynamic>>[
        _targetVariant('Server', 'server-2'),
      ],
      'except_resources': <Map<String, dynamic>>[],
      'maintenance_windows': <Map<String, dynamic>>[],
    },
  ),
  _alerterListItem(
    id: 'alerter-2',
    name: 'Email Fallback',
    enabled: false,
    endpointType: 'Email',
    tags: ['Staging'],
    config: <String, dynamic>{
      'enabled': false,
      'endpoint': <String, dynamic>{
        'type': 'Email',
        'params': <String, dynamic>{'email': 'ops@example.com'},
      },
      'alert_types': <String>['DeploymentAutoUpdated'],
      'resources': <Map<String, dynamic>>[
        _targetVariant('Deployment', 'deployment-2'),
      ],
      'except_resources': <Map<String, dynamic>>[],
      'maintenance_windows': <Map<String, dynamic>>[],
    },
  ),
  _alerterListItem(
    id: 'alerter-3',
    name: 'Ntfy Alerts',
    enabled: true,
    endpointType: 'Ntfy',
    tags: ['Incident'],
    config: <String, dynamic>{
      'enabled': true,
      'endpoint': <String, dynamic>{
        'type': 'Ntfy',
        'params': <String, dynamic>{
          'url': 'https://ntfy.sh/example',
          'email': 'demo@example.com',
        },
      },
      'alert_types': <String>['ServerUnreachable', 'BuildFailed'],
      'resources': <Map<String, dynamic>>[
        _targetVariant('Server', 'server-2'),
        _targetVariant('Build', 'build-3'),
      ],
      'except_resources': <Map<String, dynamic>>[
        _targetVariant('Server', 'server-4'),
      ],
      'maintenance_windows': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Nightly Maintenance',
          'description': 'No alerts during nightly maintenance',
          'schedule_type': 'Daily',
          'hour': 2,
          'minute': 0,
          'duration_minutes': 90,
          'timezone': 'UTC',
          'enabled': true,
        },
      ],
    },
  ),
];

final List<Map<String, dynamic>> _alerts = [
  _alertItem(
    id: 'alert-1',
    level: 'Warning',
    timestamp: DateTime.now().millisecondsSinceEpoch - 900000,
    resolved: false,
    target: _targetVariant('Server', 'server-2'),
    variant: 'ServerUnreachable',
    data: <String, dynamic>{'server_name': 'Edge Node'},
  ),
  _alertItem(
    id: 'alert-2',
    level: 'Critical',
    timestamp: DateTime.now().millisecondsSinceEpoch - 5400000,
    resolved: true,
    resolvedTs: DateTime.now().millisecondsSinceEpoch - 3600000,
    target: _targetVariant('Deployment', 'deployment-2'),
    variant: 'DeploymentAutoUpdated',
    data: <String, dynamic>{'name': 'API'},
  ),
  _alertItem(
    id: 'alert-3',
    level: 'Warning',
    timestamp: DateTime.now().millisecondsSinceEpoch - 1800000,
    resolved: false,
    target: _targetVariant('Build', 'build-3'),
    variant: 'BuildFailed',
    data: <String, dynamic>{'name': 'Billing Image'},
  ),
  _alertItem(
    id: 'alert-4',
    level: 'Ok',
    timestamp: DateTime.now().millisecondsSinceEpoch - 300000,
    resolved: true,
    resolvedTs: DateTime.now().millisecondsSinceEpoch - 240000,
    target: _targetVariant('Server', 'server-1'),
    variant: 'ServerRecovered',
    data: <String, dynamic>{'server_name': 'Primary Node'},
  ),
  _alertItem(
    id: 'alert-5',
    level: 'Warning',
    timestamp: DateTime.now().millisecondsSinceEpoch - 1200000,
    resolved: false,
    target: _targetVariant('Deployment', 'deployment-6'),
    variant: 'DeploymentRestarting',
    data: <String, dynamic>{'name': 'Metrics'},
  ),
  _alertItem(
    id: 'alert-6',
    level: 'Critical',
    timestamp: DateTime.now().millisecondsSinceEpoch - 2400000,
    resolved: true,
    resolvedTs: DateTime.now().millisecondsSinceEpoch - 1800000,
    target: _targetVariant('ResourceSync', 'sync-3'),
    variant: 'ResourceSyncFailed',
    data: <String, dynamic>{'name': 'Edge Config'},
  ),
  _alertItem(
    id: 'alert-7',
    level: 'Warning',
    timestamp: DateTime.now().millisecondsSinceEpoch - 720000,
    resolved: false,
    target: _targetVariant('Repo', 'repo-3'),
    variant: 'RepoPullFailed',
    data: <String, dynamic>{'name': 'Ops Config'},
  ),
  _alertItem(
    id: 'alert-8',
    level: 'Ok',
    timestamp: DateTime.now().millisecondsSinceEpoch - 420000,
    resolved: true,
    resolvedTs: DateTime.now().millisecondsSinceEpoch - 360000,
    target: _targetVariant('Build', 'build-2'),
    variant: 'BuildRecovered',
    data: <String, dynamic>{'name': 'Web Image'},
  ),
];

final List<Map<String, dynamic>> _updates = [
  _updateItem(
    id: 'update-1',
    operation: 'DeployStack',
    startTs: DateTime.now().millisecondsSinceEpoch - 7200000,
    success: true,
    username: 'demo',
    operatorName: 'Demo User',
    status: 'Success',
    version: const <String, dynamic>{'major': 1, 'minor': 2, 'patch': 3},
    otherData: 'stack=Production Stack',
    target: _targetVariant('Stack', 'stack-1'),
  ),
  _updateItem(
    id: 'update-2',
    operation: 'BuildImage',
    startTs: DateTime.now().millisecondsSinceEpoch - 3600000,
    success: true,
    username: 'demo',
    operatorName: 'Demo User',
    status: 'Success',
    version: const <String, dynamic>{'major': 1, 'minor': 3, 'patch': 0},
    otherData: 'build=API Image',
    target: _targetVariant('Build', 'build-1'),
  ),
  _updateItem(
    id: 'update-3',
    operation: 'SyncResources',
    startTs: DateTime.now().millisecondsSinceEpoch - 2400000,
    success: false,
    username: 'demo',
    operatorName: 'Demo User',
    status: 'Failed',
    version: const <String, dynamic>{'major': 1, 'minor': 2, 'patch': 8},
    otherData: 'sync=Edge Config',
    target: _targetVariant('ResourceSync', 'sync-3'),
  ),
  _updateItem(
    id: 'update-4',
    operation: 'PullRepo',
    startTs: DateTime.now().millisecondsSinceEpoch - 1200000,
    success: false,
    username: 'automation',
    operatorName: 'Scheduler',
    status: 'Running',
    version: const <String, dynamic>{'major': 1, 'minor': 4, 'patch': 1},
    otherData: 'repo=Komodo Web',
    target: _targetVariant('Repo', 'repo-2'),
  ),
  _updateItem(
    id: 'update-5',
    operation: 'DeployStack',
    startTs: DateTime.now().millisecondsSinceEpoch - 600000,
    success: false,
    username: 'demo',
    operatorName: 'Demo User',
    status: 'Queued',
    version: const <String, dynamic>{'major': 1, 'minor': 4, 'patch': 2},
    otherData: 'stack=Staging Stack',
    target: _targetVariant('Stack', 'stack-2'),
  ),
  _updateItem(
    id: 'update-6',
    operation: 'RestartDeployment',
    startTs: DateTime.now().millisecondsSinceEpoch - 540000,
    success: true,
    username: 'automation',
    operatorName: 'Scheduler',
    status: 'Success',
    version: const <String, dynamic>{'major': 1, 'minor': 4, 'patch': 2},
    otherData: 'deployment=Metrics',
    target: _targetVariant('Deployment', 'deployment-6'),
  ),
  _updateItem(
    id: 'update-7',
    operation: 'BuildImage',
    startTs: DateTime.now().millisecondsSinceEpoch - 420000,
    success: false,
    username: 'demo',
    operatorName: 'Demo User',
    status: 'Failed',
    version: const <String, dynamic>{'major': 1, 'minor': 4, 'patch': 2},
    otherData: 'build=Billing Image',
    target: _targetVariant('Build', 'build-3'),
  ),
  _updateItem(
    id: 'update-8',
    operation: 'SyncResources',
    startTs: DateTime.now().millisecondsSinceEpoch - 300000,
    success: true,
    username: 'demo',
    operatorName: 'Demo User',
    status: 'Success',
    version: const <String, dynamic>{'major': 1, 'minor': 4, 'patch': 2},
    otherData: 'sync=Resource Sync',
    target: _targetVariant('ResourceSync', 'sync-1'),
  ),
  _updateItem(
    id: 'update-9',
    operation: 'PullRepo',
    startTs: DateTime.now().millisecondsSinceEpoch - 210000,
    success: true,
    username: 'automation',
    operatorName: 'Scheduler',
    status: 'Success',
    version: const <String, dynamic>{'major': 1, 'minor': 4, 'patch': 3},
    otherData: 'repo=Komodo API',
    target: _targetVariant('Repo', 'repo-1'),
  ),
];

class DemoBackend {
  DemoBackend({required this.apiKey, required this.apiSecret, this.port = 0});

  final String apiKey;
  final String apiSecret;
  final int port;

  HttpServer? _server;

  Uri get baseUri {
    final server = _server;
    if (server == null) {
      throw StateError('DemoBackend not started');
    }
    return Uri.parse('http://127.0.0.1:${server.port}');
  }

  String get baseUrl => baseUri.toString();

  Future<void> start() async {
    if (_server != null) return;

    // Load demo UI-defined stack compose.yml from assets.
    // This makes it obvious that the demo stack is configurable.
    try {
      final loaded = await rootBundle.loadString(
        'assets/demo_mode/ui_defined_stack/compose.yml',
      );
      if (loaded.trim().isNotEmpty) {
        _demoUiStackComposeYml = loaded;
      }
    } catch (_) {
      // Keep fallback.
    }

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException {
      if (port == 0) rethrow;
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }
    unawaited(_serve());
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;

    await for (final request in server) {
      try {
        if (request.method != 'POST') {
          _jsonError(request, 405, 'Only POST is supported');
          continue;
        }

        final incomingKey = request.headers.value('X-Api-Key') ?? '';
        final incomingSecret = request.headers.value('X-Api-Secret') ?? '';
        if (incomingKey != apiKey || incomingSecret != apiSecret) {
          _jsonError(request, 401, 'Invalid API credentials');
          continue;
        }

        final rawBody = await utf8.decoder.bind(request).join();
        final decoded = jsonDecode(rawBody);
        if (decoded is! Map<String, dynamic>) {
          _jsonError(request, 400, 'Invalid JSON body');
          continue;
        }

        final type = decoded['type'];
        final params = decoded['params'];
        if (type is! String || (params != null && params is! Map)) {
          _jsonError(request, 400, 'Invalid RPC shape');
          continue;
        }

        final paramsMap = (params is Map)
            ? params.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};

        final response = _handleRpc(request.uri.path, type, paramsMap);
        await _jsonOk(request, response);
      } on Object catch (e) {
        _jsonError(request, 500, 'Unhandled demo backend error: $e');
      }
    }
  }

  Object _handleRpc(String path, String type, Map<String, dynamic> params) {
    switch (path) {
      case '/read':
        return _handleRead(type, params);
      case '/write':
        return _handleWrite(type, params);
      case '/execute':
        return _handleExecute(type, params);
      case '/auth':
        return <String, dynamic>{};
      default:
        return <String, dynamic>{};
    }
  }

  Object _handleRead(String type, Map<String, dynamic> params) {
    switch (type) {
      case 'GetVersion':
        return <String, dynamic>{'version': '0.0.0-demo'};
      case 'GetUsername':
        return <String, dynamic>{'username': 'Demo User'};

      case 'ListServers':
        return List<Map<String, dynamic>>.from(_servers);
      case 'GetServer':
        return _serverDetail(id: params['server']?.toString());
      case 'GetSystemStats':
        return _systemStats();
      case 'GetSystemInformation':
        return _systemInformation();

      case 'ListDeployments':
        return List<Map<String, dynamic>>.from(_deployments);
      case 'GetDeployment':
        return _deploymentDetail(id: params['deployment']?.toString());

      case 'ListStacks':
        return List<Map<String, dynamic>>.from(_stacks);
      case 'GetStack':
        return _stackDetail(id: params['stack']?.toString());
      case 'ListStackServices':
        return _stackServices();
      case 'GetStackLog':
        return _stackLog();

      case 'ListRepos':
        return List<Map<String, dynamic>>.from(_repos);
      case 'GetRepo':
        return _repoDetail(id: params['repo']?.toString());

      case 'ListBuilds':
        return List<Map<String, dynamic>>.from(_builds);
      case 'GetBuild':
        return _buildDetail(id: params['build']?.toString());
      case 'GetBuilder':
        return _builderDetail(id: params['builder']?.toString());

      case 'ListResourceSyncs':
        return List<Map<String, dynamic>>.from(_syncs);
      case 'GetResourceSync':
        return _syncDetail(id: params['sync']?.toString());

      case 'ListProcedures':
        return List<Map<String, dynamic>>.from(_procedures);
      case 'GetProcedure':
        return _procedureDetail(id: params['procedure']?.toString());

      case 'ListActions':
        return List<Map<String, dynamic>>.from(_actions);
      case 'GetAction':
        return _actionDetail(id: params['action']?.toString());

      case 'ListDockerContainers':
        return List<Map<String, dynamic>>.from(_containers);
      case 'GetContainerLog':
        return _containerLog();

      case 'ListTags':
        return List<Map<String, dynamic>>.from(_tags);
      case 'ListVariables':
        return List<Map<String, dynamic>>.from(_variables);
      case 'ListAlerts':
        return _alertsPage(params);
      case 'ListUpdates':
        return _updatesPage(params);
      case 'ListGitProviderAccounts':
        return List<Map<String, dynamic>>.from(_gitProviderAccounts);
      case 'ListDockerRegistryAccounts':
        return List<Map<String, dynamic>>.from(_dockerRegistryAccounts);
      case 'ListBuilders':
        return List<Map<String, dynamic>>.from(_builders);
      case 'ListAlerters':
        return List<Map<String, dynamic>>.from(_alerters);
      case 'GetAlerter':
        return _alerterDetail(id: params['alerter']?.toString());

      default:
        if (type.startsWith('List')) {
          return <Object>[];
        }
        return <String, dynamic>{};
    }
  }

  Object _handleWrite(String type, Map<String, dynamic> params) {
    switch (type) {
      case 'CreateTag':
        final name = (params['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) return <String, dynamic>{};
        final created = _tag(
          id: 'tag-${_tags.length + 1}',
          name: name,
          colorToken: (params['color'] as String?)?.trim() ?? 'Slate',
        );
        _tags.add(created);
        return created;
      case 'DeleteTag':
        final id = (params['id'] as String?)?.trim() ?? '';
        _tags.removeWhere((t) => t['id'] == id);
        return <String, dynamic>{};
      case 'RenameTag':
        final id = (params['id'] as String?)?.trim() ?? '';
        final name = (params['name'] as String?)?.trim() ?? '';
        final index = _tags.indexWhere((t) => t['id'] == id);
        if (index != -1 && name.isNotEmpty) {
          _tags[index] = {..._tags[index], 'name': name};
        }
        return <String, dynamic>{};
      case 'UpdateTagColor':
        final tagIdOrName = (params['tag'] as String?)?.trim() ?? '';
        final colorToken = (params['color'] as String?)?.trim() ?? '';
        final index = _tags.indexWhere(
          (t) => t['id'] == tagIdOrName || t['name'] == tagIdOrName,
        );
        if (index != -1 && colorToken.isNotEmpty) {
          _tags[index] = {..._tags[index], 'color': colorToken};
        }
        return <String, dynamic>{};

      case 'CreateGitProviderAccount':
        final account = params['account'];
        if (account is Map) {
          final id = 'git-${_gitProviderAccounts.length + 1}';
          final created = _gitProviderAccount(
            id: id,
            domain: account['domain']?.toString() ?? '',
            username: account['username']?.toString() ?? '',
            https: account['https'] == true,
            token: account['token']?.toString() ?? '',
          );
          _gitProviderAccounts.add(created);
          return created;
        }
        return <String, dynamic>{};
      case 'UpdateGitProviderAccount':
        final id = params['id']?.toString() ?? '';
        final account = params['account'];
        final index = _gitProviderAccounts.indexWhere((a) => a['id'] == id);
        if (index != -1 && account is Map) {
          _gitProviderAccounts[index] = {
            ..._gitProviderAccounts[index],
            if (account['domain'] != null) 'domain': account['domain'],
            if (account['username'] != null) 'username': account['username'],
            if (account['https'] != null) 'https': account['https'],
            if (account['token'] != null) 'token': account['token'],
          };
          return _gitProviderAccounts[index];
        }
        return <String, dynamic>{};
      case 'DeleteGitProviderAccount':
        final id = params['id']?.toString() ?? '';
        final index = _gitProviderAccounts.indexWhere((a) => a['id'] == id);
        if (index != -1) {
          final removed = _gitProviderAccounts.removeAt(index);
          return removed;
        }
        return <String, dynamic>{};

      case 'CreateDockerRegistryAccount':
        final account = params['account'];
        if (account is Map) {
          final id = 'registry-${_dockerRegistryAccounts.length + 1}';
          final created = _dockerRegistryAccount(
            id: id,
            domain: account['domain']?.toString() ?? '',
            username: account['username']?.toString() ?? '',
            token: account['token']?.toString() ?? '',
          );
          _dockerRegistryAccounts.add(created);
          return created;
        }
        return <String, dynamic>{};
      case 'UpdateDockerRegistryAccount':
        final id = params['id']?.toString() ?? '';
        final account = params['account'];
        final index = _dockerRegistryAccounts.indexWhere((a) => a['id'] == id);
        if (index != -1 && account is Map) {
          _dockerRegistryAccounts[index] = {
            ..._dockerRegistryAccounts[index],
            if (account['domain'] != null) 'domain': account['domain'],
            if (account['username'] != null) 'username': account['username'],
            if (account['token'] != null) 'token': account['token'],
          };
          return _dockerRegistryAccounts[index];
        }
        return <String, dynamic>{};
      case 'DeleteDockerRegistryAccount':
        final id = params['id']?.toString() ?? '';
        final index = _dockerRegistryAccounts.indexWhere((a) => a['id'] == id);
        if (index != -1) {
          final removed = _dockerRegistryAccounts.removeAt(index);
          return removed;
        }
        return <String, dynamic>{};

      case 'RenameBuilder':
        final id = params['id']?.toString() ?? '';
        final name = params['name']?.toString() ?? '';
        final index = _builders.indexWhere((b) => b['id'] == id);
        if (index != -1 && name.isNotEmpty) {
          _builders[index] = {..._builders[index], 'name': name};
        }
        return <String, dynamic>{};
      case 'DeleteBuilder':
        final id = params['id']?.toString() ?? '';
        _builders.removeWhere((b) => b['id'] == id);
        return <String, dynamic>{};
      case 'UpdateBuilder':
        final id = params['id']?.toString() ?? '';
        final config = params['config'];
        final index = _builders.indexWhere((b) => b['id'] == id);
        if (index != -1 && config is Map) {
          _builders[index] = {
            ..._builders[index],
            'config': config.map((k, v) => MapEntry(k.toString(), v)),
          };
        }
        return <String, dynamic>{};

      case 'RenameAlerter':
        final id = params['id']?.toString() ?? '';
        final name = params['name']?.toString() ?? '';
        final index = _alerters.indexWhere((a) => a['id'] == id);
        if (index != -1 && name.isNotEmpty) {
          _alerters[index] = {..._alerters[index], 'name': name};
        }
        return <String, dynamic>{};
      case 'DeleteAlerter':
        final id = params['id']?.toString() ?? '';
        _alerters.removeWhere((a) => a['id'] == id);
        return <String, dynamic>{};
      case 'UpdateAlerter':
        final id = params['id']?.toString() ?? '';
        final config = params['config'];
        final index = _alerters.indexWhere((a) => a['id'] == id);
        if (index != -1 && config is Map) {
          final enabled = config['enabled'];
          final existingInfo = _alerters[index]['info'];
          final infoMap = existingInfo is Map
              ? existingInfo.map((k, v) => MapEntry(k.toString(), v))
              : <String, dynamic>{};
          _alerters[index] = {
            ..._alerters[index],
            if (enabled is bool)
              'info': <String, dynamic>{
                ...infoMap,
                'enabled': enabled,
              },
            'config': config.map((k, v) => MapEntry(k.toString(), v)),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
        }
        return <String, dynamic>{};

      default:
        return <String, dynamic>{};
    }
  }

  Object _handleExecute(String type, Map<String, dynamic> params) {
    switch (type) {
      case 'DestroyDeployment':
        final deploymentId = params['deployment']?.toString();
        if (deploymentId != null) {
          _deployments.removeWhere(
            (d) => d['id'] == deploymentId || d['name'] == deploymentId,
          );
        }
        return <String, dynamic>{};
      case 'DestroyStack':
        final stackId = params['stack']?.toString();
        if (stackId != null) {
          _stacks.removeWhere(
            (s) => s['id'] == stackId || s['name'] == stackId,
          );
        }
        return <String, dynamic>{};
      case 'StopContainer':
      case 'RestartContainer':
        return <String, dynamic>{};
      case 'TestAlerter':
        return <String, dynamic>{};
      default:
        return <String, dynamic>{};
    }
  }
}

Map<String, dynamic> _serverItem({
  required String id,
  required String name,
  required String address,
  required String region,
  required String state,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': 'Demo server running Komodo',
    'tags': <String>[],
    'template': false,
    'info': <String, dynamic>{
      'state': state,
      'region': region,
      'address': address,
      'external_address': address,
      'version': '1.2.3',
      'send_unreachable_alerts': true,
      'send_cpu_alerts': true,
      'send_mem_alerts': true,
      'send_disk_alerts': true,
      'send_version_mismatch_alerts': true,
      'terminals_disabled': false,
      'container_exec_disabled': false,
    },
  };
}

Map<String, dynamic> _serverDetail({required String? id}) {
  final match = id == null ? null : _serverById(id) ?? _serverByName(id);
  final server = match ?? _servers.first;
  return <String, dynamic>{
    ...server,
    'config': <String, dynamic>{
      'address': server['info']?['address'] ?? '10.0.0.10',
      'external_address': server['info']?['external_address'] ?? '10.0.0.10',
      'region': server['info']?['region'] ?? 'us-east-1',
      'enabled': true,
      'timeout_seconds': 30,
      'passkey': '',
      'ignore_mounts': <String>[],
      'stats_monitoring': true,
      'auto_prune': false,
      'links': <String>[],
      'send_unreachable_alerts': true,
      'send_cpu_alerts': true,
      'send_mem_alerts': true,
      'send_disk_alerts': true,
      'send_version_mismatch_alerts': true,
      'cpu_warning': 70,
      'cpu_critical': 90,
      'mem_warning': 75,
      'mem_critical': 90,
      'disk_warning': 80,
      'disk_critical': 92,
      'maintenance_windows': <Object>[],
    },
  };
}

Map<String, dynamic> _deployment({
  required String id,
  required String name,
  required String description,
  required String state,
  required String image,
  required String serverId,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': description,
    'tags': <String>[],
    'template': false,
    'info': <String, dynamic>{
      'state': state,
      'status': null,
      'image': image,
      'update_available': false,
      'server_id': serverId,
      'build_id': null,
    },
  };
}

Map<String, dynamic> _deploymentDetail({required String? id}) {
  final match = id == null
      ? null
      : _deploymentById(id) ?? _deploymentByName(id);
  final deployment = match ?? _deployments.first;
  return <String, dynamic>{
    ...deployment,
    'config': <String, dynamic>{
      'server_id': deployment['info']?['server_id'] ?? 'server-1',
      'image': deployment['info']?['image'] ?? 'nginx:latest',
      'image_registry_account': '',
      'skip_secret_interp': false,
      'redeploy_on_build': false,
      'poll_for_updates': true,
      'auto_update': false,
      'send_alerts': true,
      'links': <String>[],
      'network': '',
      'restart': 'Always',
      'command': '',
      'termination_signal': null,
      'termination_timeout': 10,
      'extra_args': <String>[],
      'term_signal_labels': '',
      'ports': '80:80',
      'volumes': '',
      'environment': 'ENV=demo',
      'labels': '',
    },
  };
}

Map<String, dynamic> _stackListItem({
  required String id,
  required String name,
  required String serverId,
  required String repo,
  required String branch,
  required String state,
  bool fileContents = false,
  bool filesOnHost = false,
  String gitProvider = 'GitHub',
  String? linkedRepo,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'template': false,
    'tags': <String>[],
    'info': <String, dynamic>{
      'server_id': serverId,
      'files_on_host': filesOnHost,
      'file_contents': fileContents,
      'git_provider': gitProvider,
      'state': state,
      'status': null,
      'repo': repo,
      'branch': branch,
      'linked_repo': linkedRepo ?? repo,
      'repo_link': repo.isEmpty ? '' : 'https://github.com/$repo',
      'services': [
        <String, dynamic>{
          'service': 'web',
          'image': 'nginx:latest',
          'update_available': false,
        },
      ],
      'missing_files': <String>[],
      'deployed_hash': null,
      'latest_hash': null,
      'project_missing': false,
    },
  };
}

Map<String, dynamic> _stackDetail({required String? id}) {
  final match = id == null ? null : _stackById(id) ?? _stackByName(id);
  final stack = match ?? _stacks.first;
  final isUiDefined = stack['info']?['file_contents'] == true;
  return <String, dynamic>{
    'id': stack['id'],
    'name': stack['name'],
    'description': 'Primary deployment stack',
    'template': false,
    'tags': <String>[],
    'config': <String, dynamic>{
      'server_id': stack['info']?['server_id'] ?? 'server-1',
      'links': <String>[],
      'project_name': 'komodo',
      'auto_pull': true,
      'run_build': true,
      'destroy_before_deploy': false,
      'linked_repo': isUiDefined ? '' : (stack['info']?['linked_repo'] ?? ''),
      'repo': isUiDefined ? '' : (stack['info']?['repo'] ?? ''),
      'branch': isUiDefined ? '' : (stack['info']?['branch'] ?? ''),
      'commit': '',
      'clone_path': '/srv/komodo',
      'reclone': false,
      'run_directory': '/srv/komodo',
      'auto_update': false,
      'poll_for_updates': true,
      'send_alerts': true,
      'webhook_enabled': false,
      'webhook_force_deploy': false,
      'webhook_secret': '',
      'files_on_host': false,
      'file_paths': <String>[],
      'env_file_path': '',
      'file_contents': isUiDefined ? _demoUiStackComposeYml : '',
      'use_internal_registry': false,
      'include_services': <String>[],
      'exclude_services': <String>[],
      'use_compose_config': false,
      'compose_config': '',
      'compose_extends': <String>[],
      'compose_file_path': 'docker-compose.yml',
      'git_https': true,
      'git_account': 'demo',
      'skip_secret_interp': false,
    },
    'info': <String, dynamic>{
      'missing_files': <String>[],
      'deployed_config': null,
      'remote_contents': <Object>[],
      'remote_errors': <Object>[],
      'deployed_hash': 'abc123',
      'latest_hash': 'abc123',
      'latest_message': 'Initial demo deploy',
      'deployed_message': 'Initial demo deploy',
    },
  };
}

List<Map<String, dynamic>> _stackServices() {
  return [
    <String, dynamic>{
      'service': 'web',
      'image': 'nginx:latest',
      'update_available': false,
      'container': <String, dynamic>{
        'name': 'web-1',
        'state': 'running',
        'status': 'Up 2 hours',
        'image': 'nginx:latest',
        'id': 'container-1',
      },
    },
    <String, dynamic>{
      'service': 'api',
      'image': 'ghcr.io/komodo/api:1.2.3',
      'update_available': true,
      'container': <String, dynamic>{
        'name': 'api-1',
        'state': 'running',
        'status': 'Up 2 hours',
        'image': 'ghcr.io/komodo/api:1.2.3',
        'id': 'container-2',
      },
    },
  ];
}

Map<String, dynamic> _stackLog() {
  return <String, dynamic>{
    'stage': 'deploy',
    'command': 'docker compose up -d',
    'stdout': [
      'Pulling web (nginx:latest)...',
      'Pulling api (ghcr.io/komodo/api:1.2.3)...',
      'Pulling worker (ghcr.io/komodo/worker:2.0.1)...',
      'Creating network "komodo_default" with the default driver',
      'Creating komodo-web-1 ... done',
      'Creating komodo-api-1 ... done',
      'Creating komodo-worker-1 ... done',
      'Waiting for healthchecks (api, worker)',
      '✔ api healthy',
      '✔ worker healthy',
      'Services started',
    ].join('\n'),
    'stderr': '',
    'success': true,
    'start_ts': DateTime.now().millisecondsSinceEpoch - 5000,
    'end_ts': DateTime.now().millisecondsSinceEpoch - 1000,
  };
}

Map<String, dynamic> _alertItem({
  required String id,
  required String level,
  required int timestamp,
  required bool resolved,
  required Map<String, dynamic> target,
  required String variant,
  required Map<String, dynamic> data,
  int? resolvedTs,
}) {
  return <String, dynamic>{
    'id': id,
    'ts': timestamp,
    'resolved': resolved,
    'level': level,
    'target': target,
    'data': <String, dynamic>{variant: data},
    if (resolvedTs != null) 'resolved_ts': resolvedTs,
  };
}

Map<String, dynamic> _updateItem({
  required String id,
  required String operation,
  required int startTs,
  required bool success,
  required String username,
  required String operatorName,
  required String status,
  required Map<String, dynamic> version,
  required String otherData,
  required Map<String, dynamic> target,
}) {
  return <String, dynamic>{
    'id': id,
    'operation': operation,
    'start_ts': startTs,
    'success': success,
    'username': username,
    'operator': operatorName,
    'status': status,
    'version': version,
    'other_data': otherData,
    'target': target,
  };
}

Map<String, dynamic> _targetVariant(String variant, String id) {
  return <String, dynamic>{variant: id};
}

Map<String, dynamic> _alertsPage(Map<String, dynamic> params) {
  final page = _readPage(params['page']);
  if (page > 0) {
    return <String, dynamic>{'alerts': <Object>[], 'next_page': null};
  }
  return <String, dynamic>{'alerts': _alerts, 'next_page': null};
}

Map<String, dynamic> _updatesPage(Map<String, dynamic> params) {
  final page = _readPage(params['page']);
  if (page > 0) {
    return <String, dynamic>{'updates': <Object>[], 'next_page': null};
  }
  return <String, dynamic>{'updates': _updates, 'next_page': null};
}

int _readPage(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Map<String, dynamic> _repoListItem({
  required String id,
  required String name,
  required String serverId,
  required String builderId,
  required String repo,
  required String branch,
  required String state,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'template': false,
    'tags': <String>[],
    'info': <String, dynamic>{
      'server_id': serverId,
      'builder_id': builderId,
      'git_provider': 'GitHub',
      'repo': repo,
      'branch': branch,
      'repo_link': 'https://github.com/$repo',
      'state': state,
      'last_pulled_at': DateTime.now().millisecondsSinceEpoch - 3600000,
      'last_built_at': DateTime.now().millisecondsSinceEpoch - 7200000,
      'cloned_hash': 'abc123',
      'cloned_message': 'Demo commit',
      'built_hash': 'abc123',
      'latest_hash': 'abc123',
    },
  };
}

Map<String, dynamic> _repoDetail({required String? id}) {
  final match = id == null ? null : _repoById(id) ?? _repoByName(id);
  final repo = match ?? _repos.first;
  return <String, dynamic>{
    'id': repo['id'],
    'name': repo['name'],
    'description': 'Demo repository',
    'template': false,
    'tags': <String>[],
    'config': <String, dynamic>{
      'server_id': repo['info']?['server_id'] ?? 'server-1',
      'builder_id': repo['info']?['builder_id'] ?? 'builder-1',
      'git_provider': 'GitHub',
      'git_https': true,
      'git_account': 'demo',
      'repo': repo['info']?['repo'] ?? 'komodo/api',
      'branch': repo['info']?['branch'] ?? 'main',
      'commit': 'abc123',
      'path': '/srv/komodo',
      'webhook_enabled': false,
      'skip_secret_interp': false,
    },
    'info': <String, dynamic>{
      'last_pulled_at': DateTime.now().millisecondsSinceEpoch - 3600000,
      'last_built_at': DateTime.now().millisecondsSinceEpoch - 7200000,
      'built_hash': 'abc123',
      'built_message': 'Demo build',
      'latest_hash': 'abc123',
      'latest_message': 'Demo commit',
    },
  };
}

Map<String, dynamic> _buildListItem({
  required String id,
  required String name,
  required String builderId,
  required String repo,
  required String branch,
  required String state,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'template': false,
    'tags': <String>[],
    'info': <String, dynamic>{
      'state': state,
      'last_built_at': DateTime.now().millisecondsSinceEpoch - 7200000,
      'version': <String, dynamic>{'major': 1, 'minor': 2, 'patch': 3},
      'builder_id': builderId,
      'linked_repo': repo,
      'repo': repo,
      'branch': branch,
      'repo_link': 'https://github.com/$repo',
      'built_hash': 'abc123',
      'latest_hash': 'abc123',
      'image_registry_domain': 'ghcr.io',
    },
  };
}

Map<String, dynamic> _buildDetail({required String? id}) {
  final match = id == null ? null : _buildById(id) ?? _buildByName(id);
  final build = match ?? _builds.first;
  return <String, dynamic>{
    'id': build['id'],
    'name': build['name'],
    'description': 'Demo build pipeline',
    'template': false,
    'tags': <String>[],
    'config': <String, dynamic>{
      'builder_id': build['info']?['builder_id'] ?? 'builder-1',
      'version': <String, dynamic>{'major': 1, 'minor': 2, 'patch': 3},
      'auto_increment_version': false,
      'image_name': 'komodo/api',
      'image_tag': '1.2.3',
      'linked_repo': build['info']?['linked_repo'] ?? 'komodo/api',
      'repo': build['info']?['repo'] ?? 'komodo/api',
      'branch': build['info']?['branch'] ?? 'main',
      'commit': 'abc123',
      'webhook_enabled': false,
      'files_on_host': false,
      'build_path': '/srv/komodo',
      'dockerfile_path': 'Dockerfile',
      'skip_secret_interp': false,
      'use_buildx': false,
      'extra_args': <String>[],
    },
    'info': <String, dynamic>{
      'last_built_at': DateTime.now().millisecondsSinceEpoch - 7200000,
      'built_hash': 'abc123',
      'built_message': 'Demo build',
      'built_contents': null,
      'remote_path': null,
      'remote_contents': null,
      'remote_error': null,
      'latest_hash': 'abc123',
      'latest_message': 'Demo commit',
    },
  };
}

Map<String, dynamic> _builderDetail({required String? id}) {
  final match = id == null ? null : _builderById(id) ?? _builderByName(id);
  final builder = match ?? _builders.first;
  final builderType =
      (builder['info']?['builder_type'] ?? builder['builder_type'] ?? 'Url')
          .toString();

  final storedConfig = builder['config'];
  final config = storedConfig is Map
      ? storedConfig.map((k, v) => MapEntry(k.toString(), v))
      : switch (builderType) {
          'Server' => <String, dynamic>{
              'Server': <String, dynamic>{'server_id': 'server-2'},
            },
          'Aws' => <String, dynamic>{
              'Aws': <String, dynamic>{
                'region': 'us-east-1',
                'instance_type': 't3.medium',
                'volume_gb': 50,
                'port': 2376,
                'use_https': true,
                'assign_public_ip': true,
                'use_public_ip': false,
              },
            },
          _ => <String, dynamic>{
              'Url': <String, dynamic>{
                'address': 'https://builders.example.com',
                'passkey': 'demo-passkey',
              },
            },
        };

  return <String, dynamic>{
    'id': builder['id'],
    'name': builder['name'],
    'description': 'Demo builder for $builderType workloads',
    'template': builder['template'] ?? false,
    'tags': builder['tags'] ?? <String>[],
    'config': config,
  };
}

Map<String, dynamic> _builderListItem({
  required String id,
  required String name,
  required String builderType,
  required String? instanceType,
  Map<String, dynamic>? config,
  List<String> tags = const <String>[],
  bool template = false,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'template': template,
    'tags': tags,
    if (config != null) 'config': config,
    'info': <String, dynamic>{
      'builder_type': builderType,
      'instance_type': instanceType,
    },
  };
}

Map<String, dynamic> _alerterListItem({
  required String id,
  required String name,
  required bool enabled,
  required String endpointType,
  Map<String, dynamic>? config,
  List<String> tags = const <String>[],
  bool template = false,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'template': template,
    'tags': tags,
    if (config != null) 'config': config,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'info': <String, dynamic>{
      'enabled': enabled,
      'endpoint_type': endpointType,
    },
  };
}

Map<String, dynamic> _gitProviderAccount({
  required String id,
  required String domain,
  required String username,
  required bool https,
  required String token,
}) {
  return <String, dynamic>{
    'id': id,
    'domain': domain,
    'username': username,
    'https': https,
    'token': token,
  };
}

Map<String, dynamic> _dockerRegistryAccount({
  required String id,
  required String domain,
  required String username,
  required String token,
}) {
  return <String, dynamic>{
    'id': id,
    'domain': domain,
    'username': username,
    'token': token,
  };
}

Map<String, dynamic> _alerterDetail({required String? id}) {
  final match = id == null ? null : _alerterById(id) ?? _alerterByName(id);
  final alerter = match ?? _alerters.first;
  final now = DateTime.now().toUtc().toIso8601String();
  final endpointType =
      (alerter['info']?['endpoint_type'] ?? 'Slack').toString();

  final storedConfig = alerter['config'];
  if (storedConfig is Map) {
    final configMap = storedConfig.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{
      'alerter': <String, dynamic>{
        'id': alerter['id'],
        'name': alerter['name'],
        'updated_at': alerter['updated_at'] ?? now,
      },
      'updated_at': alerter['updated_at'] ?? now,
      'config': configMap,
    };
  }

  final endpoint = switch (endpointType) {
    'Email' => <String, dynamic>{
        'type': 'Email',
        'params': <String, dynamic>{'email': 'ops@example.com'},
      },
    'Ntfy' => <String, dynamic>{
        'type': 'Ntfy',
        'params': <String, dynamic>{
          'url': 'https://ntfy.sh/example',
          'email': 'demo@example.com',
        },
      },
    _ => <String, dynamic>{
        'type': 'Slack',
        'params': <String, dynamic>{
          'url': 'https://hooks.slack.com/services/demo/demo/demo',
        },
      },
  };

  return <String, dynamic>{
    'alerter': <String, dynamic>{
      'id': alerter['id'],
      'name': alerter['name'],
      'updated_at': now,
    },
    'updated_at': now,
    'config': <String, dynamic>{
      'enabled': alerter['info']?['enabled'] ?? false,
      'endpoint': endpoint,
      'alert_types': <String>[
        'ServerUnreachable',
        'BuildFailed',
        'DeploymentAutoUpdated',
      ],
      'resources': <Map<String, dynamic>>[
        _targetVariant('Server', 'server-2'),
        _targetVariant('Build', 'build-3'),
      ],
      'except_resources': <Map<String, dynamic>>[
        _targetVariant('Server', 'server-4'),
      ],
      'maintenance_windows': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Nightly Maintenance',
          'description': 'No alerts during nightly maintenance',
          'schedule_type': 'Daily',
          'hour': 2,
          'minute': 0,
          'duration_minutes': 90,
          'timezone': 'UTC',
          'enabled': true,
        },
      ],
    },
  };
}

Map<String, dynamic> _syncListItem({
  required String id,
  required String name,
  required String repo,
  required String branch,
  required String state,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'template': false,
    'tags': <String>[],
    'info': <String, dynamic>{
      'last_sync_ts': DateTime.now().millisecondsSinceEpoch - 7200000,
      'files_on_host': false,
      'file_contents': false,
      'managed': true,
      'resource_path': <String>['resources'],
      'linked_repo': repo,
      'git_provider': 'GitHub',
      'repo': repo,
      'branch': branch,
      'repo_link': 'https://github.com/$repo',
      'last_sync_hash': 'abc123',
      'last_sync_message': 'Demo sync',
      'state': state,
    },
  };
}

Map<String, dynamic> _syncDetail({required String? id}) {
  final match = id == null ? null : _syncById(id) ?? _syncByName(id);
  final sync = match ?? _syncs.first;
  return <String, dynamic>{
    'id': sync['id'],
    'name': sync['name'],
    'description': 'Sync shared resources',
    'template': false,
    'tags': <String>[],
    'config': <String, dynamic>{
      'linked_repo': sync['info']?['linked_repo'] ?? 'komodo/ops-config',
      'git_provider': 'GitHub',
      'git_https': true,
      'repo': sync['info']?['repo'] ?? 'komodo/ops-config',
      'branch': sync['info']?['branch'] ?? 'main',
      'commit': 'abc123',
      'git_account': 'demo',
      'webhook_enabled': false,
      'webhook_secret': '',
      'files_on_host': false,
      'resource_path': <String>['resources'],
      'managed': true,
      'delete': false,
      'include_resources': true,
      'match_tags': <String>[],
      'include_variables': true,
      'include_user_groups': false,
      'pending_alert': false,
      'file_contents': '',
    },
    'info': <String, dynamic>{
      'last_sync_ts': DateTime.now().millisecondsSinceEpoch - 7200000,
      'last_sync_hash': 'abc123',
      'last_sync_message': 'Demo sync',
      'pending_error': null,
      'pending_hash': null,
      'pending_message': null,
    },
  };
}

Map<String, dynamic> _procedureListItem({
  required String id,
  required String name,
  required int stages,
  required String state,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'template': false,
    'tags': <String>[],
    'info': <String, dynamic>{
      'stages': stages,
      'state': state,
      'last_run_at': DateTime.now().millisecondsSinceEpoch - 3600000,
      'next_scheduled_run': DateTime.now().millisecondsSinceEpoch + 3600000,
      'schedule_error': null,
    },
  };
}

Map<String, dynamic> _procedureDetail({required String? id}) {
  final match = id == null ? null : _procedureById(id) ?? _procedureByName(id);
  final procedure = match ?? _procedures.first;
  final stages = _procedureStagesFor(
    id: procedure['id']?.toString(),
    name: procedure['name']?.toString(),
  );
  return <String, dynamic>{
    'id': procedure['id'],
    'name': procedure['name'],
    'description': 'Routine maintenance',
    'template': false,
    'tags': <String>[],
    'config': <String, dynamic>{
      'stages': stages,
      'schedule_format': 'English',
      'schedule': 'Every day at 02:00',
      'schedule_enabled': true,
      'schedule_timezone': 'UTC',
      'schedule_alert': false,
      'failure_alert': true,
      'webhook_enabled': false,
      'webhook_secret': '',
    },
  };
}

List<Map<String, dynamic>> _procedureStagesFor({
  required String? id,
  required String? name,
}) {
  switch (id ?? name ?? '') {
    case 'procedure-1':
    case 'Nightly Cleanup':
      return [
        _procedureStage(
          name: 'Preflight checks',
          executions: [
            _execution(command: 'komodo health --format=json'),
          ],
        ),
        _procedureStage(
          name: 'Cleanup resources',
          executions: [
            _execution(command: 'docker system prune -af', timeout: '5m'),
            _execution(command: 'rm -rf /tmp/komodo-cache', enabled: false),
          ],
        ),
        _procedureStage(
          name: 'Report',
          executions: [
            _execution(
              command: 'notify --channel=ops --message="Cleanup complete"',
            ),
          ],
        ),
      ];
    case 'procedure-2':
    case 'Rotate Secrets':
      return [
        _procedureStage(
          name: 'Freeze writes',
          executions: [
            _execution(command: 'komodo maintenance enable'),
          ],
        ),
        _procedureStage(
          name: 'Rotate database',
          executions: [
            _typedExecution(
              'RotateSecret',
              params: {
                'target': 'postgres',
                'path': 'secret/prod/db',
              },
            ),
          ],
        ),
        _procedureStage(
          name: 'Rotate API keys',
          executions: [
            _typedExecution(
              'RotateSecret',
              params: {
                'target': 'api',
                'path': 'secret/prod/api',
              },
            ),
            _typedExecution(
              'RotateSecret',
              params: {
                'target': 'worker',
                'path': 'secret/prod/worker',
              },
              enabled: false,
            ),
          ],
        ),
        _procedureStage(
          name: 'Restart services',
          executions: [
            _typedExecution(
              'RestartService',
              params: {'service': 'api'},
            ),
            _typedExecution(
              'RestartService',
              params: {'service': 'worker'},
            ),
          ],
        ),
        _procedureStage(
          name: 'Notify',
          executions: [
            _execution(
              command:
                  'notify --channel=security --message="Secrets rotated"',
            ),
          ],
        ),
      ];
    case 'procedure-3':
    case 'Incident Drill':
      return [
        _procedureStage(
          name: 'Simulate outage',
          executions: [
            _execution(command: 'komodo drill start --scenario=region-failure'),
          ],
        ),
        _procedureStage(
          name: 'Restore',
          executions: [
            _execution(command: 'komodo drill stop'),
            _execution(
              command: 'notify --channel=incident --message="Drill complete"',
            ),
          ],
        ),
      ];
    default:
      return [
        _procedureStage(
          name: 'Default stage',
          executions: [
            _typedExecution('RunBuild'),
          ],
        ),
      ];
  }
}

Map<String, dynamic> _procedureStage({
  required String name,
  required List<Map<String, dynamic>> executions,
  bool enabled = true,
}) {
  return <String, dynamic>{
    'name': name,
    'enabled': enabled,
    'executions': executions,
  };
}

Map<String, dynamic> _execution({
  required String command,
  bool enabled = true,
  String? timeout,
}) {
  return <String, dynamic>{
    'enabled': enabled,
    'execution': <String, dynamic>{
      'type': 'RunCommand',
      'command': command,
      if (timeout != null) 'timeout': timeout,
    },
  };
}

Map<String, dynamic> _typedExecution(
  String type, {
  Map<String, dynamic>? params,
  bool enabled = true,
}) {
  return <String, dynamic>{
    'enabled': enabled,
    'execution': <String, dynamic>{
      'type': type,
      if (params != null) 'params': params,
    },
  };
}

Map<String, dynamic> _actionListItem({
  required String id,
  required String name,
  required String state,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'template': false,
    'tags': <String>[],
    'info': <String, dynamic>{
      'state': state,
      'last_run_at': DateTime.now().millisecondsSinceEpoch - 5400000,
      'next_scheduled_run': null,
      'schedule_error': null,
    },
  };
}

Map<String, dynamic> _actionDetail({required String? id}) {
  final match = id == null ? null : _actionById(id) ?? _actionByName(id);
  final action = match ?? _actions.first;
  return <String, dynamic>{
    'id': action['id'],
    'name': action['name'],
    'description': 'Restart the frontend service',
    'template': false,
    'tags': <String>[],
    'config': <String, dynamic>{
      'run_at_startup': false,
      'schedule_format': 'English',
      'schedule': 'On demand',
      'schedule_enabled': false,
      'schedule_timezone': 'UTC',
      'schedule_alert': false,
      'failure_alert': true,
      'webhook_enabled': false,
      'webhook_secret': '',
      'reload_deno_deps': false,
      'file_contents': '',
      'arguments_format': 'KeyValue',
      'arguments': 'service=frontend',
    },
  };
}

Map<String, dynamic> _containerListItem({
  required String serverId,
  required String name,
  required String image,
  required String status,
  required String state,
}) {
  return <String, dynamic>{
    'server_id': serverId,
    'name': name,
    'id': 'container-$name',
    'image': image,
    'status': status,
    'state': state,
    'networks': <String>['bridge'],
    'ports': [
      <String, dynamic>{
        'ip': '0.0.0.0',
        'private_port': 80,
        'public_port': 8080,
        'type': 'tcp',
      },
    ],
    'stats': <String, dynamic>{
      'cpu_perc': '2.4%',
      'mem_perc': '1.8%',
      'mem_usage': '128MiB / 8GiB',
      'net_io': '1.2MB / 980kB',
      'block_io': '0B / 0B',
      'pids': '12',
    },
  };
}

Map<String, dynamic> _containerLog() {
  return <String, dynamic>{
    'stage': 'logs',
    'command': 'docker logs',
    'stdout': 'Service started\nReady to accept connections',
    'stderr': '',
    'success': true,
    'start_ts': DateTime.now().millisecondsSinceEpoch - 3000,
    'end_ts': DateTime.now().millisecondsSinceEpoch - 1000,
  };
}

Map<String, dynamic> _tag({
  required String id,
  required String name,
  required String colorToken,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'owner': '',
    'color': colorToken,
  };
}

Map<String, dynamic> _variable({
  required String id,
  required String name,
  required String description,
  required String value,
  required bool isSecret,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': description,
    'value': value,
    'is_secret': isSecret,
  };
}

Map<String, dynamic> _systemStats() {
  return <String, dynamic>{
    'cpu_perc': 12.5,
    'load_average': <String, dynamic>{'one': 0.4, 'five': 0.6, 'fifteen': 0.5},
    'mem_free_gb': 6.2,
    'mem_used_gb': 1.8,
    'mem_total_gb': 8.0,
    'disks': [
      <String, dynamic>{
        'mount': '/',
        'file_system': 'apfs',
        'used_gb': 32.0,
        'total_gb': 128.0,
      },
    ],
    'network_ingress_bytes': 123456.0,
    'network_egress_bytes': 654321.0,
    'refresh_ts': DateTime.now().millisecondsSinceEpoch,
    'refresh_list_ts': DateTime.now().millisecondsSinceEpoch,
  };
}

Map<String, dynamic> _systemInformation() {
  return <String, dynamic>{
    'name': 'Demo Server',
    'os': 'Linux',
    'kernel': '6.5.0',
    'core_count': 8,
    'host_name': 'demo-node',
    'cpu_brand': 'Apple M3',
    'terminals_disabled': false,
    'container_exec_disabled': false,
  };
}

Map<String, dynamic>? _serverById(String id) {
  return _servers.cast<Map<String, dynamic>?>().firstWhere(
    (s) => s?['id'] == id,
    orElse: () => null,
  );
}

Map<String, dynamic>? _serverByName(String name) {
  return _servers.cast<Map<String, dynamic>?>().firstWhere(
    (s) => s?['name'] == name,
    orElse: () => null,
  );
}

Map<String, dynamic>? _deploymentById(String id) {
  return _deployments.cast<Map<String, dynamic>?>().firstWhere(
    (d) => d?['id'] == id,
    orElse: () => null,
  );
}

Map<String, dynamic>? _deploymentByName(String name) {
  return _deployments.cast<Map<String, dynamic>?>().firstWhere(
    (d) => d?['name'] == name,
    orElse: () => null,
  );
}

Map<String, dynamic>? _stackById(String id) {
  return _stacks.cast<Map<String, dynamic>?>().firstWhere(
    (s) => s?['id'] == id,
    orElse: () => null,
  );
}

Map<String, dynamic>? _stackByName(String name) {
  return _stacks.cast<Map<String, dynamic>?>().firstWhere(
    (s) => s?['name'] == name,
    orElse: () => null,
  );
}

Map<String, dynamic>? _repoById(String id) {
  return _repos.cast<Map<String, dynamic>?>().firstWhere(
    (r) => r?['id'] == id,
    orElse: () => null,
  );
}

Map<String, dynamic>? _repoByName(String name) {
  return _repos.cast<Map<String, dynamic>?>().firstWhere(
    (r) => r?['name'] == name,
    orElse: () => null,
  );
}

Map<String, dynamic>? _buildById(String id) {
  return _builds.cast<Map<String, dynamic>?>().firstWhere(
    (b) => b?['id'] == id,
    orElse: () => null,
  );
}

Map<String, dynamic>? _buildByName(String name) {
  return _builds.cast<Map<String, dynamic>?>().firstWhere(
    (b) => b?['name'] == name,
    orElse: () => null,
  );
}

Map<String, dynamic>? _builderById(String id) {
  return _builders.cast<Map<String, dynamic>?>().firstWhere(
    (b) => b?['id'] == id,
    orElse: () => null,
  );
}

Map<String, dynamic>? _builderByName(String name) {
  return _builders.cast<Map<String, dynamic>?>().firstWhere(
    (b) => b?['name'] == name,
    orElse: () => null,
  );
}

Map<String, dynamic>? _syncById(String id) {
  return _syncs.cast<Map<String, dynamic>?>().firstWhere(
    (s) => s?['id'] == id,
    orElse: () => null,
  );
}

Map<String, dynamic>? _syncByName(String name) {
  return _syncs.cast<Map<String, dynamic>?>().firstWhere(
    (s) => s?['name'] == name,
    orElse: () => null,
  );
}

Map<String, dynamic>? _procedureById(String id) {
  return _procedures.cast<Map<String, dynamic>?>().firstWhere(
    (p) => p?['id'] == id,
    orElse: () => null,
  );
}

Map<String, dynamic>? _procedureByName(String name) {
  return _procedures.cast<Map<String, dynamic>?>().firstWhere(
    (p) => p?['name'] == name,
    orElse: () => null,
  );
}

Map<String, dynamic>? _actionById(String id) {
  return _actions.cast<Map<String, dynamic>?>().firstWhere(
    (a) => a?['id'] == id,
    orElse: () => null,
  );
}

Map<String, dynamic>? _actionByName(String name) {
  return _actions.cast<Map<String, dynamic>?>().firstWhere(
    (a) => a?['name'] == name,
    orElse: () => null,
  );
}

Map<String, dynamic>? _alerterById(String id) {
  return _alerters.cast<Map<String, dynamic>?>().firstWhere(
    (a) => a?['id'] == id,
    orElse: () => null,
  );
}

Map<String, dynamic>? _alerterByName(String name) {
  return _alerters.cast<Map<String, dynamic>?>().firstWhere(
    (a) => a?['name'] == name,
    orElse: () => null,
  );
}

Future<void> _jsonOk(HttpRequest request, Object body) async {
  request.response.statusCode = 200;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

void _jsonError(HttpRequest request, int statusCode, String message) {
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.json;
  request.response.write(
    jsonEncode(<String, dynamic>{'error': message, 'trace': null}),
  );
  request.response.close();
}
