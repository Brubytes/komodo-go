import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';

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

T expectRight<T>(Either<Failure, T> result) {
  return result.fold(
    (failure) => fail('Expected success, got $failure'),
    (value) => value,
  );
}

Failure expectLeft<T>(Either<Failure, T> result) {
  return result.fold(
    (failure) => failure,
    (value) => fail('Expected failure, got $value'),
  );
}

ServerFailure expectServerFailure<T>(
  Either<Failure, T> result, {
  String? messageContains,
}) {
  final failure = expectLeft(result);
  expect(failure, isA<ServerFailure>());
  final serverFailure = failure as ServerFailure;
  if (messageContains != null && messageContains.isNotEmpty) {
    expect(serverFailure.message, contains(messageContains));
  }
  return serverFailure;
}

AuthFailure expectAuthFailure<T>(Either<Failure, T> result) {
  final failure = expectLeft(result);
  expect(failure, isA<AuthFailure>());
  return failure as AuthFailure;
}

Future<ServerFailure> expectEventuallyServerFailure<T>(
  Future<Either<Failure, T>> Function() action, {
  String? messageContains,
  int attempts = 6,
  Duration delay = const Duration(milliseconds: 300),
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    final result = await action();
    if (result.isLeft()) {
      return expectServerFailure(result, messageContains: messageContains);
    }
    await Future<void>.delayed(delay);
  }
  fail('Expected server failure, but action kept succeeding.');
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

String readIdFromMap(Map<String, dynamic> json) {
  if (json.containsKey('id')) {
    return json['id'].toString();
  }
  if (json.containsKey('_id')) {
    final id = json['_id'];
    if (id is Map && id.containsKey(r'$oid')) {
      return id[r'$oid'].toString();
    }
    return id.toString();
  }
  return '';
}

Future<T> retryAsync<T>(
  Future<T> Function() action, {
  int attempts = 5,
  Duration delay = const Duration(milliseconds: 300),
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      return await action();
    } on Object catch (error) {
      lastError = error;
      if (attempt == attempts - 1) break;
      await Future<void>.delayed(delay);
    }
  }
  throw StateError('retryAsync failed: $lastError');
}

Future<String> waitForListItemId({
  required Future<List<dynamic>> Function() listItems,
  required String name,
  int attempts = 10,
  Duration delay = const Duration(milliseconds: 300),
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    final items = await listItems();
    for (final item in items) {
      if (item is Map && item['name']?.toString() == name) {
        return readIdFromMap(item.cast<String, dynamic>());
      }
    }
    await Future<void>.delayed(delay);
  }
  throw StateError('Item not found in list: $name');
}
