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

  final List<Map<String, dynamic>> _stacks = <Map<String, dynamic>>[
    _stack(id: 'stack-1', name: 'Test Stack'),
  ];

  final List<Map<String, dynamic>> _tags = <Map<String, dynamic>>[
    _tag(id: 'tag-1', name: 'Test Tag', owner: '', colorToken: 'Slate'),
  ];
  int _tagIdCounter = 2;

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

        final response = _handleRpc(request.uri.path, type, paramsMap);
        await _jsonOk(request, response);
      } on Object catch (e) {
        _jsonError(request, 500, 'Unhandled fake backend error: $e');
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

      // Settings: Komodo
      case 'ListTags':
        return List<Map<String, dynamic>>.from(_tags);

      case 'ListDeployments':
      case 'ListRepos':
      case 'ListBuilds':
      case 'ListResourceSyncs':
      case 'ListProcedures':
      case 'ListActions':
      case 'ListServers':
        return <Object>[];

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

      default:
        throw StateError('Unhandled /execute RPC: $type');
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

Future<void> _jsonOk(HttpRequest request, Object body) async {
  request.response.statusCode = 200;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

void _jsonError(HttpRequest request, int statusCode, String message) {
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(<String, dynamic>{
    'error': message,
    'trace': null,
  }));
  request.response.close();
}
