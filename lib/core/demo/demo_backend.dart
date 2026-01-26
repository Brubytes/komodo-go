import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
];

final List<Map<String, dynamic>> _stacks = [
  _stackListItem(
    id: 'stack-1',
    name: 'Production Stack',
    serverId: 'server-1',
    repo: 'komodo/production-stack',
    branch: 'main',
    state: 'Running',
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
];

final List<Map<String, dynamic>> _syncs = [
  _syncListItem(
    id: 'sync-1',
    name: 'Resource Sync',
    repo: 'komodo/ops-config',
    branch: 'main',
    state: 'Ok',
  ),
];

final List<Map<String, dynamic>> _procedures = [
  _procedureListItem(
    id: 'procedure-1',
    name: 'Nightly Cleanup',
    stages: 3,
    state: 'Ok',
  ),
];

final List<Map<String, dynamic>> _actions = [
  _actionListItem(id: 'action-1', name: 'Restart Web', state: 'Ok'),
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
];

final List<Map<String, dynamic>> _tags = [
  _tag(id: 'tag-1', name: 'Production', colorToken: 'Emerald'),
  _tag(id: 'tag-2', name: 'Staging', colorToken: 'Blue'),
];

final List<Map<String, dynamic>> _variables = [
  _variable(
    id: 'var-1',
    name: 'REGION',
    description: 'Default region for deployments',
    value: 'us-east-1',
    isSecret: false,
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
      case 'ListDockerRegistryAccounts':
      case 'ListBuilders':
      case 'ListAlerters':
        return <Object>[];
      case 'GetAlerter':
        return <String, dynamic>{};

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
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'template': false,
    'tags': <String>[],
    'info': <String, dynamic>{
      'server_id': serverId,
      'files_on_host': false,
      'file_contents': false,
      'git_provider': 'GitHub',
      'state': state,
      'status': null,
      'repo': repo,
      'branch': branch,
      'linked_repo': repo,
      'repo_link': 'https://github.com/$repo',
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
      'linked_repo': stack['info']?['linked_repo'] ?? '',
      'repo': stack['info']?['repo'] ?? '',
      'branch': stack['info']?['branch'] ?? '',
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
      'update_available': false,
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
    'stdout': 'Services started',
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
  return <String, dynamic>{'id': id ?? 'builder-1', 'name': 'Default Builder'};
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
  return <String, dynamic>{
    'id': procedure['id'],
    'name': procedure['name'],
    'description': 'Routine maintenance',
    'template': false,
    'tags': <String>[],
    'config': <String, dynamic>{
      'stages': <Object>[],
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
