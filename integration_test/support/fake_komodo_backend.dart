import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RecordedRpcCall {
  RecordedRpcCall({
    required this.path,
    required this.type,
    required this.params,
    required this.headers,
    required this.rawBody,
  });

  final String path;
  final String type;
  final Map<String, dynamic> params;
  final HttpHeaders headers;
  final String rawBody;
}

class FakeRpcOverride {
  FakeRpcOverride.success({
    required this.path,
    required this.type,
    this.body,
    this.delay,
  }) : statusCode = 200,
       message = null;

  FakeRpcOverride.error({
    required this.path,
    required this.type,
    required this.statusCode,
    required this.message,
    this.delay,
  }) : body = null;

  final String path;
  final String type;
  final int statusCode;
  final String? message;
  final Object? body;
  final Duration? delay;

  bool get isError => statusCode != 200;
}

class FakeRpcResponseException implements Exception {
  FakeRpcResponseException(this.statusCode, this.message);

  final int statusCode;
  final String message;
}

/// Minimal in-process fake backend that implements the subset of Komodo RPC
/// needed for deterministic integration tests.
class FakeKomodoBackend {
  FakeKomodoBackend({
    required this.expectedApiKey,
    required this.expectedApiSecret,
    this.port = 0,
  });

  final String expectedApiKey;
  final String expectedApiSecret;
  final int port;

  HttpServer? _server;
  final List<RecordedRpcCall> calls = <RecordedRpcCall>[];
  final Map<String, List<FakeRpcOverride>> _overrides =
      <String, List<FakeRpcOverride>>{};

  final List<Map<String, dynamic>> _stacks = <Map<String, dynamic>>[
    _stack(id: 'stack-1', name: 'Test Stack'),
  ];
  final Map<String, Map<String, dynamic>> _stackDetails =
      <String, Map<String, dynamic>>{
        'stack-1': _stackDetail(
          id: 'stack-1',
          name: 'Test Stack',
          serverId: 'server-1',
        ),
      };
  final Map<String, List<Map<String, dynamic>>> _stackServices =
      <String, List<Map<String, dynamic>>>{
        'stack-1': [
          _stackService(
            service: 'web',
            image: 'nginx:latest',
            updateAvailable: false,
          ),
        ],
      };
  final Map<String, Map<String, dynamic>> _stackLogs =
      <String, Map<String, dynamic>>{
        'stack-1': _stackLog(stdout: 'Stack log: hello from fake backend'),
      };

  final List<Map<String, dynamic>> _tags = <Map<String, dynamic>>[
    _tag(id: 'tag-1', name: 'Test Tag', owner: '', colorToken: 'Slate'),
  ];
  int _tagIdCounter = 2;

  final List<Map<String, dynamic>> _deployments = <Map<String, dynamic>>[
    _deployment(
      id: 'deployment-1',
      name: 'Test Deployment',
      description: 'Fake backend deployment',
      state: 'running',
      image: 'nginx:latest',
      serverId: 'server-1',
    ),
  ];

  final List<Map<String, dynamic>> _servers = <Map<String, dynamic>>[
    _serverListItem(
      id: 'server-1',
      name: 'Test Server',
      address: '10.0.0.1',
      region: 'us-east-1',
      version: '1.2.3',
      state: 'Ok',
    ),
  ];
  final Map<String, Map<String, dynamic>> _serverDetails =
      <String, Map<String, dynamic>>{
        'server-1': _serverDetail(
          id: 'server-1',
          name: 'Test Server',
          address: '10.0.0.1',
          region: 'us-east-1',
          version: '1.2.3',
        ),
      };
  final Map<String, Map<String, dynamic>> _serverStats =
      <String, Map<String, dynamic>>{'server-1': _systemStats()};
  final Map<String, Map<String, dynamic>> _serverSystemInfo =
      <String, Map<String, dynamic>>{'server-1': _systemInfo()};

  final List<Map<String, dynamic>> _builds = <Map<String, dynamic>>[
    _buildListItem(
      id: 'build-1',
      name: 'Test Build',
      state: 'Ok',
      repo: 'org/repo',
      branch: 'main',
      version: const {'major': 1, 'minor': 0, 'patch': 0},
    ),
  ];

  final List<Map<String, dynamic>> _procedures = <Map<String, dynamic>>[
    _procedureListItem(
      id: 'procedure-1',
      name: 'Test Procedure',
      stages: 3,
      state: 'Ok',
    ),
  ];

  final List<Map<String, dynamic>> _actions = <Map<String, dynamic>>[
    _actionListItem(id: 'action-1', name: 'Test Action', state: 'Ok'),
  ];

  final List<Map<String, dynamic>> _repos = <Map<String, dynamic>>[
    _repoListItem(
      id: 'repo-1',
      name: 'Test Repo',
      state: 'Ok',
      repo: 'org/repo',
      branch: 'main',
    ),
  ];

  final List<Map<String, dynamic>> _syncs = <Map<String, dynamic>>[
    _syncListItem(
      id: 'sync-1',
      name: 'Test Sync',
      state: 'Ok',
      repo: 'org/repo',
      branch: 'main',
    ),
  ];

  final Map<String, List<Map<String, dynamic>>> _containersByServer =
      <String, List<Map<String, dynamic>>>{
        'server-1': [
          _containerListItem(
            id: 'container-1',
            name: 'nginx',
            image: 'nginx:latest',
            state: 'Running',
          ),
        ],
      };
  final Map<String, Map<String, dynamic>> _containerLogs =
      <String, Map<String, dynamic>>{
        'container-1': _containerLog(stdout: 'Container log: hello world'),
        'nginx': _containerLog(stdout: 'Container log: hello world'),
      };

  Uri get baseUri {
    final server = _server;
    if (server == null) {
      throw StateError('FakeKomodoBackend not started');
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

  void resetCalls() => calls.clear();

  void queueError({
    required String path,
    required String type,
    required int statusCode,
    required String message,
    Duration? delay,
  }) {
    _queueOverride(
      FakeRpcOverride.error(
        path: path,
        type: type,
        statusCode: statusCode,
        message: message,
        delay: delay,
      ),
    );
  }

  void queueResponse({
    required String path,
    required String type,
    required Object body,
    Duration? delay,
  }) {
    _queueOverride(
      FakeRpcOverride.success(path: path, type: type, body: body, delay: delay),
    );
  }

  void _queueOverride(FakeRpcOverride override) {
    final key = _overrideKey(override.path, override.type);
    final queue = _overrides.putIfAbsent(key, () => <FakeRpcOverride>[]);
    queue.add(override);
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

        final apiKey = request.headers.value('X-Api-Key');
        final apiSecret = request.headers.value('X-Api-Secret');
        if (apiKey != expectedApiKey || apiSecret != expectedApiSecret) {
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

        calls.add(
          RecordedRpcCall(
            path: request.uri.path,
            type: type,
            params: paramsMap,
            headers: request.headers,
            rawBody: rawBody,
          ),
        );

        final override = _dequeueOverride(request.uri.path, type);
        if (override != null) {
          if (override.delay != null) {
            await Future<void>.delayed(override.delay!);
          }
          if (override.isError) {
            _jsonError(
              request,
              override.statusCode,
              override.message ?? 'Fake backend error',
            );
          } else {
            await _jsonOk(request, override.body ?? <String, dynamic>{});
          }
          continue;
        }

        final response = _handleRpc(request.uri.path, type, paramsMap);
        await _jsonOk(request, response);
      } on FakeRpcResponseException catch (e) {
        _jsonError(request, e.statusCode, e.message);
      } on Object catch (e) {
        _jsonError(request, 500, 'Unhandled fake backend error: $e');
      }
    }
  }

  FakeRpcOverride? _dequeueOverride(String path, String type) {
    final key = _overrideKey(path, type);
    final queue = _overrides[key];
    if (queue == null || queue.isEmpty) return null;
    return queue.removeAt(0);
  }

  String _overrideKey(String path, String type) => '$path::$type';

  Object _handleRpc(String path, String type, Map<String, dynamic> params) {
    switch (path) {
      case '/read':
        return _handleRead(type, params);
      case '/write':
        return _handleWrite(type, params);
      case '/execute':
        return _handleExecute(type, params);
      case '/auth':
        return _handleAuth(type, params);
      default:
        throw StateError('Unhandled path: $path');
    }
  }

  Object _handleAuth(String type, Map<String, dynamic> params) {
    throw StateError('Unhandled /auth RPC: $type');
  }

  Object _handleRead(String type, Map<String, dynamic> params) {
    switch (type) {
      case 'GetVersion':
        return <String, dynamic>{'version': '0.0.0-test'};

      case 'GetUsername':
        final userId = (params['user_id'] as String?)?.trim() ?? '';
        if (userId.isEmpty) {
          return <String, dynamic>{'username': ''};
        }
        return <String, dynamic>{'username': 'Test User'};

      // Resources cards and list views
      case 'ListStacks':
        return List<Map<String, dynamic>>.from(_stacks);

      case 'GetStack':
        final idOrName = (params['stack'] as String?)?.trim() ?? '';
        final detail =
            _stackDetails[idOrName] ??
            _stackDetails.values.firstWhere(
              (item) => item['name'] == idOrName,
              orElse: () => <String, dynamic>{},
            );
        if (detail.isEmpty) {
          throw FakeRpcResponseException(404, 'Stack not found');
        }
        return detail;

      case 'ListStackServices':
        final idOrName = (params['stack'] as String?)?.trim() ?? '';
        final services =
            _stackServices[idOrName] ??
            _stackServices.values.firstWhere(
              (items) => items.any((service) => service['service'] == idOrName),
              orElse: () => <Map<String, dynamic>>[],
            );
        return List<Map<String, dynamic>>.from(services);

      case 'GetStackLog':
        final idOrName = (params['stack'] as String?)?.trim() ?? '';
        return _stackLogs[idOrName] ??
            _stackLog(stdout: 'Stack log: (missing stack)');

      // Settings: Komodo
      case 'ListTags':
        return List<Map<String, dynamic>>.from(_tags);

      case 'ListDeployments':
        return List<Map<String, dynamic>>.from(_deployments);
      case 'GetDeployment':
        final idOrName = (params['deployment'] as String?)?.trim() ?? '';
        final deployment = _deployments.firstWhere(
          (d) => d['id'] == idOrName || d['name'] == idOrName,
          orElse: () => <String, dynamic>{},
        );
        if (deployment.isEmpty) {
          throw FakeRpcResponseException(404, 'Deployment not found');
        }
        return _deploymentDetail(deployment);
      case 'ListServers':
        return List<Map<String, dynamic>>.from(_servers);
      case 'ListBuilds':
        return List<Map<String, dynamic>>.from(_builds);
      case 'ListProcedures':
        return List<Map<String, dynamic>>.from(_procedures);
      case 'ListActions':
        return List<Map<String, dynamic>>.from(_actions);
      case 'ListDockerContainers':
        final serverId = (params['server'] as String?)?.trim() ?? '';
        return List<Map<String, dynamic>>.from(
          _containersByServer[serverId] ?? <Map<String, dynamic>>[],
        );
      case 'GetContainerLog':
        final container = (params['container'] as String?)?.trim() ?? '';
        return _containerLogs[container] ??
            _containerLog(stdout: 'Container log: (missing container)');
      case 'GetServer':
        final idOrName = (params['server'] as String?)?.trim() ?? '';
        final detail =
            _serverDetails[idOrName] ??
            _serverDetails.values.firstWhere(
              (item) => item['name'] == idOrName,
              orElse: () => <String, dynamic>{},
            );
        if (detail.isEmpty) {
          throw FakeRpcResponseException(404, 'Server not found');
        }
        return detail;
      case 'GetSystemStats':
        final idOrName = (params['server'] as String?)?.trim() ?? '';
        return _serverStats[idOrName] ?? _systemStats();
      case 'GetSystemInformation':
        final idOrName = (params['server'] as String?)?.trim() ?? '';
        return _serverSystemInfo[idOrName] ?? _systemInfo();

      case 'ListRepos':
        return List<Map<String, dynamic>>.from(_repos);
      case 'ListResourceSyncs':
        return List<Map<String, dynamic>>.from(_syncs);

      default:
        throw StateError('Unhandled /read RPC: $type');
    }
  }

  Object _handleWrite(String type, Map<String, dynamic> params) {
    switch (type) {
      case 'CreateTag':
        final name = (params['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) {
          throw StateError('CreateTag missing name');
        }
        final colorToken = (params['color'] as String?)?.trim();
        final created = _tag(
          id: 'tag-${_tagIdCounter++}',
          name: name,
          owner: '',
          colorToken: colorToken?.isEmpty ?? true ? 'Slate' : colorToken!,
        );
        _tags.add(created);
        return created;

      case 'DeleteTag':
        final id = (params['id'] as String?)?.trim() ?? '';
        final index = _tags.indexWhere((t) => t['id'] == id);
        if (index == -1) {
          throw StateError('DeleteTag: not found: $id');
        }
        final deleted = _tags.removeAt(index);
        return deleted;

      case 'RenameTag':
        final id = (params['id'] as String?)?.trim() ?? '';
        final name = (params['name'] as String?)?.trim() ?? '';
        final index = _tags.indexWhere((t) => t['id'] == id);
        if (index == -1) {
          throw StateError('RenameTag: not found: $id');
        }
        if (name.isEmpty) {
          throw StateError('RenameTag missing name');
        }
        final updated = Map<String, dynamic>.from(_tags[index]);
        updated['name'] = name;
        _tags[index] = updated;
        return updated;

      case 'UpdateTagColor':
        final tagIdOrName = (params['tag'] as String?)?.trim() ?? '';
        final colorToken = (params['color'] as String?)?.trim() ?? '';
        if (tagIdOrName.isEmpty) {
          throw StateError('UpdateTagColor missing tag');
        }
        if (colorToken.isEmpty) {
          throw StateError('UpdateTagColor missing color');
        }

        final index = _tags.indexWhere(
          (t) => t['id'] == tagIdOrName || t['name'] == tagIdOrName,
        );
        if (index == -1) {
          throw StateError('UpdateTagColor: not found: $tagIdOrName');
        }
        final updated = Map<String, dynamic>.from(_tags[index]);
        updated['color'] = colorToken;
        _tags[index] = updated;
        return updated;

      default:
        throw StateError('Unhandled /write RPC: $type');
    }
  }

  Object _handleExecute(String type, Map<String, dynamic> params) {
    switch (type) {
      case 'DestroyStack':
        final stackIdOrName = params['stack'];
        if (stackIdOrName is String) {
          _stacks.removeWhere(
            (s) => s['id'] == stackIdOrName || s['name'] == stackIdOrName,
          );
        }
        return <String, dynamic>{};

      case 'DestroyDeployment':
        final deploymentIdOrName = params['deployment'];
        if (deploymentIdOrName is String) {
          _deployments.removeWhere(
            (d) =>
                d['id'] == deploymentIdOrName ||
                d['name'] == deploymentIdOrName,
          );
        }
        return <String, dynamic>{};

      case 'RunBuild':
        _updateBuildState(params['build'], 'Building');
        return <String, dynamic>{};
      case 'CancelBuild':
        _updateBuildState(params['build'], 'Failed');
        return <String, dynamic>{};

      case 'RunProcedure':
        _updateProcedureState(params['procedure'], 'Running');
        return <String, dynamic>{};

      case 'RunAction':
        _updateActionState(params['action'], 'Running');
        return <String, dynamic>{};

      case 'RestartContainer':
      case 'StopContainer':
        return <String, dynamic>{};

      case 'PullRepo':
      case 'CloneRepo':
      case 'BuildRepo':
        return <String, dynamic>{};

      case 'RunSync':
        return <String, dynamic>{};

      case 'DeployStack':
        return <String, dynamic>{};

      case 'Deploy':
        return <String, dynamic>{};

      default:
        throw StateError('Unhandled /execute RPC: $type');
    }
  }

  void _updateBuildState(Object? idOrName, String state) {
    if (idOrName is! String) return;
    for (final build in _builds) {
      if (build['id'] == idOrName || build['name'] == idOrName) {
        final info = Map<String, dynamic>.from(build['info'] as Map);
        info['state'] = state;
        build['info'] = info;
        return;
      }
    }
  }

  void _updateProcedureState(Object? idOrName, String state) {
    if (idOrName is! String) return;
    for (final procedure in _procedures) {
      if (procedure['id'] == idOrName || procedure['name'] == idOrName) {
        final info = Map<String, dynamic>.from(procedure['info'] as Map);
        info['state'] = state;
        procedure['info'] = info;
        return;
      }
    }
  }

  void _updateActionState(Object? idOrName, String state) {
    if (idOrName is! String) return;
    for (final action in _actions) {
      if (action['id'] == idOrName || action['name'] == idOrName) {
        final info = Map<String, dynamic>.from(action['info'] as Map);
        info['state'] = state;
        action['info'] = info;
        return;
      }
    }
  }
}

Map<String, dynamic> _stack({required String id, required String name}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'created_at': '2025-01-01T00:00:00Z',
    'updated_at': '2025-01-01T00:00:00Z',
    'description': null,
    'tags': <Object>[],
    'info': <String, dynamic>{},
    'server_id': null,
    'repo': null,
    'branch': null,
    'config_path': null,
    'linked_repo': null,
  };
}

Map<String, dynamic> _tag({
  required String id,
  required String name,
  required String owner,
  required String colorToken,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'owner': owner,
    'color': colorToken,
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
    'tags': <Object>[],
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

Map<String, dynamic> _deploymentDetail(Map<String, dynamic> deployment) {
  final info =
      deployment['info'] as Map<String, dynamic>? ?? <String, dynamic>{};
  return <String, dynamic>{
    ...deployment,
    'config': <String, dynamic>{
      'server_id': info['server_id'] ?? 'server-1',
      'image': info['image'] ?? 'nginx:latest',
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
      'environment': 'ENV=test',
      'labels': '',
    },
  };
}

Map<String, dynamic> _serverListItem({
  required String id,
  required String name,
  required String address,
  required String region,
  required String version,
  required String state,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': 'Fake backend server',
    'tags': <Object>[],
    'template': false,
    'info': <String, dynamic>{
      'state': state,
      'address': address,
      'external_address': address,
      'region': region,
      'version': version,
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

Map<String, dynamic> _serverDetail({
  required String id,
  required String name,
  required String address,
  required String region,
  required String version,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': 'Fake backend server detail',
    'tags': <Object>[],
    'template': false,
    'info': <String, dynamic>{
      'state': 'Ok',
      'address': address,
      'external_address': address,
      'region': region,
      'version': version,
      'terminals_disabled': false,
      'container_exec_disabled': false,
    },
    'config': <String, dynamic>{
      'address': address,
      'external_address': address,
      'region': region,
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
      'cpu_warning': 0,
      'cpu_critical': 0,
      'mem_warning': 0,
      'mem_critical': 0,
      'disk_warning': 0,
      'disk_critical': 0,
      'maintenance_windows': <Object>[],
    },
  };
}

Map<String, dynamic> _systemStats() {
  return <String, dynamic>{
    'cpu_perc': 12.5,
    'load_average': <String, dynamic>{
      'one': 0.42,
      'five': 0.38,
      'fifteen': 0.35,
    },
    'mem_free_gb': 12.0,
    'mem_used_gb': 4.0,
    'mem_total_gb': 16.0,
    'disks': [
      <String, dynamic>{
        'mount': '/',
        'file_system': 'ext4',
        'used_gb': 120.0,
        'total_gb': 256.0,
      },
    ],
    'network_ingress_bytes': 1024.0,
    'network_egress_bytes': 2048.0,
    'polling_rate': '2.5s',
    'refresh_ts': DateTime.now().millisecondsSinceEpoch,
    'refresh_list_ts': DateTime.now().millisecondsSinceEpoch,
  };
}

Map<String, dynamic> _systemInfo() {
  return <String, dynamic>{
    'name': 'komodo-test',
    'os': 'Ubuntu',
    'kernel': '6.6.0',
    'core_count': 4,
    'host_name': 'komodo-host',
    'cpu_brand': 'Fake CPU',
    'terminals_disabled': false,
    'container_exec_disabled': false,
  };
}

Map<String, dynamic> _stackDetail({
  required String id,
  required String name,
  required String serverId,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': 'Fake stack detail',
    'template': false,
    'tags': <Object>[],
    'config': <String, dynamic>{
      'server_id': serverId,
      'links': <String>[],
      'project_name': name,
      'auto_pull': false,
      'run_build': false,
      'destroy_before_deploy': false,
      'linked_repo': '',
      'repo': 'org/repo',
      'branch': 'main',
      'commit': '',
      'clone_path': '',
      'reclone': false,
      'run_directory': '',
      'auto_update': false,
      'poll_for_updates': false,
      'send_alerts': false,
      'webhook_enabled': false,
      'webhook_force_deploy': false,
      'webhook_secret': '',
      'files_on_host': false,
      'file_paths': <String>[],
      'env_file_path': '',
      'additional_env_files': <String>[],
      'config_files': <Object>[],
      'ignore_services': <String>[],
      'file_contents': '',
      'environment': 'prod',
      'registry_provider': '',
      'registry_account': '',
      'extra_args': <String>[],
      'build_extra_args': <String>[],
    },
    'info': <String, dynamic>{
      'missing_files': <String>[],
      'deployed_config': null,
      'remote_contents': <Object>[],
      'remote_errors': <Object>[],
      'deployed_hash': null,
      'latest_hash': null,
      'latest_message': null,
      'deployed_message': null,
    },
  };
}

Map<String, dynamic> _stackService({
  required String service,
  required String image,
  required bool updateAvailable,
}) {
  return <String, dynamic>{
    'service': service,
    'image': image,
    'update_available': updateAvailable,
    'container': <String, dynamic>{
      'name': service,
      'state': 'running',
      'status': 'Up 2 minutes',
      'image': image,
      'id': 'container-$service',
    },
  };
}

Map<String, dynamic> _stackLog({required String stdout}) {
  return <String, dynamic>{
    'stage': 'compose',
    'command': 'docker compose logs',
    'stdout': stdout,
    'stderr': '',
    'success': true,
    'start_ts': DateTime.now().millisecondsSinceEpoch,
    'end_ts': DateTime.now().millisecondsSinceEpoch,
  };
}

Map<String, dynamic> _buildListItem({
  required String id,
  required String name,
  required String state,
  required String repo,
  required String branch,
  required Map<String, dynamic> version,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'template': false,
    'tags': <Object>[],
    'info': <String, dynamic>{
      'state': state,
      'last_built_at': 0,
      'version': version,
      'builder_id': '',
      'linked_repo': '',
      'repo': repo,
      'branch': branch,
      'repo_link': '',
      'built_hash': null,
      'latest_hash': null,
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
    'tags': <Object>[],
    'info': <String, dynamic>{
      'stages': stages,
      'state': state,
      'last_run_at': null,
      'next_scheduled_run': null,
      'schedule_error': null,
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
    'tags': <Object>[],
    'info': <String, dynamic>{
      'state': state,
      'last_run_at': null,
      'next_scheduled_run': null,
      'schedule_error': null,
    },
  };
}

Map<String, dynamic> _containerListItem({
  required String id,
  required String name,
  required String image,
  required String state,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'image': image,
    'status': 'Up 2 minutes',
    'state': state,
    'networks': <String>['bridge'],
    'ports': [
      <String, dynamic>{
        'ip': '0.0.0.0',
        'private_port': 80,
        'public_port': 8080,
        'type': 'Tcp',
      },
    ],
    'stats': <String, dynamic>{
      'cpu_perc': '1.2%',
      'mem_perc': '2.4%',
      'mem_usage': '24.0MiB / 128.0MiB',
      'net_io': '1.2kB / 1.5kB',
      'block_io': '0B / 0B',
      'pids': '2',
    },
  };
}

Map<String, dynamic> _containerLog({required String stdout}) {
  return <String, dynamic>{
    'stage': 'container',
    'command': 'docker logs',
    'stdout': stdout,
    'stderr': '',
    'success': true,
    'start_ts': DateTime.now().millisecondsSinceEpoch,
    'end_ts': DateTime.now().millisecondsSinceEpoch,
  };
}

Map<String, dynamic> _repoListItem({
  required String id,
  required String name,
  required String state,
  required String repo,
  required String branch,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'template': false,
    'tags': <Object>[],
    'info': <String, dynamic>{
      'state': state,
      'repo': repo,
      'branch': branch,
      'git_provider': '',
      'repo_link': '',
      'latest_hash': null,
      'latest_message': null,
      'built_hash': null,
      'built_message': null,
      'last_pulled_at': 0,
      'last_built_at': 0,
    },
  };
}

Map<String, dynamic> _syncListItem({
  required String id,
  required String name,
  required String state,
  required String repo,
  required String branch,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'template': false,
    'tags': <Object>[],
    'info': <String, dynamic>{
      'state': state,
      'repo': repo,
      'branch': branch,
      'git_provider': '',
      'linked_repo': '',
      'resource_path': <String>[],
      'last_sync_ts': 0,
      'last_sync_hash': null,
      'last_sync_message': null,
      'pending_error': null,
    },
  };
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
