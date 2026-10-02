import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_control_repository.g.dart';

/// Coordinates instance-wide image checks without applying auto-updates.
class UpdateControlRepository {
  UpdateControlRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, String?>> checkGlobalCandidates() {
    return apiCall(() async {
      final response = await _client.execute(
        const RpcRequest(
          type: 'GlobalAutoUpdate',
          params: <String, dynamic>{'skip_auto_update': true},
        ),
      );
      final updateId = _readId(response);
      if (updateId != null) await _waitForCompletion(updateId);
      return updateId;
    });
  }

  Future<void> _waitForCompletion(String updateId) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final response = await _client.read(
        RpcRequest(type: 'GetUpdate', params: {'id': updateId}),
      );
      if (response is Map) {
        final status = response['status']?.toString().toLowerCase();
        if (status == 'complete' ||
            status == 'failed' ||
            status == 'canceled') {
          return;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  static String? _readId(Object? response) {
    if (response is! Map) return null;
    final raw = response['id'] ?? response['_id'];
    final value = raw is Map ? raw[r'$oid'] : raw;
    return value is String && value.isNotEmpty ? value : null;
  }
}

@riverpod
UpdateControlRepository? updateControlRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  return client == null ? null : UpdateControlRepository(client);
}
