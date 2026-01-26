import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/api_client.dart';

import 'backend_test_config.dart';

class RpcRecorder {
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<Response<dynamic>> responses = <Response<dynamic>>[];

  RequestOptions? get lastRequest =>
      requests.isEmpty ? null : requests[requests.length - 1];

  Response<dynamic>? get lastResponse =>
      responses.isEmpty ? null : responses[responses.length - 1];
}

Dio buildTestDio(BackendTestConfig config, {RpcRecorder? recorder}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      contentType: 'application/json',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'X-Api-Key': config.apiKey,
        'X-Api-Secret': config.apiSecret,
      },
    ),
  );

  if (recorder != null) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          recorder.requests.add(options);
          handler.next(options);
        },
        onResponse: (response, handler) {
          recorder.responses.add(response);
          handler.next(response);
        },
      ),
    );
  }

  return dio;
}

KomodoApiClient buildTestClient(BackendTestConfig config, RpcRecorder recorder) {
  return KomodoApiClient(buildTestDio(config, recorder: recorder));
}

Future<void> resetBackendIfConfigured(BackendTestConfig config) async {
  final resetCommand = config.resetCommand;
  if (resetCommand == null) return;

  final result = await Process.run(
    resetCommand,
    const <String>[],
    runInShell: true,
  );
  if (result.exitCode != 0) {
    fail(
      'Reset command failed (exit ${result.exitCode}).\n'
      'stdout: ${result.stdout}\n'
      'stderr: ${result.stderr}',
    );
  }
}

Map<String, dynamic> loadGoldenJson(String relativePath) {
  final file = File(relativePath);
  if (!file.existsSync()) {
    fail('Missing golden snapshot: ${file.path}');
  }
  final raw = file.readAsStringSync();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    fail('Golden snapshot must be a JSON object: ${file.path}');
  }
  return decoded;
}

Map<String, dynamic> normalizeJson(Map<String, dynamic> json) {
  final normalized = <String, dynamic>{};
  for (final entry in json.entries) {
    final value = entry.value;
    if (value is Map) {
      normalized[entry.key] = normalizeJson(value.cast<String, dynamic>());
    } else if (value is List) {
      normalized[entry.key] = value.map((item) {
        if (item is Map) return normalizeJson(item.cast<String, dynamic>());
        return item;
      }).toList();
    } else {
      normalized[entry.key] = value;
    }
  }
  return normalized;
}
