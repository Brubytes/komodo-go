import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/core_info.dart';

part 'core_repository.g.dart';

class CoreRepository {
  CoreRepository(this._client);

  final KomodoApiClient _client;

  Future<CoreInfo> getCoreInfo() async {
    final res = await _client.read(
      const RpcRequest(type: 'GetCoreInfo', params: <String, dynamic>{}),
    );
    return CoreInfo.fromJson(res as Map<String, dynamic>);
  }
}

@riverpod
CoreRepository? coreRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return CoreRepository(client);
}
