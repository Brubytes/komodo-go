import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/core_info.dart';
import '../data/repositories/core_repository.dart';

part 'core_info_provider.g.dart';

@riverpod
Future<CoreInfo> coreInfo(Ref ref) async {
  final repo = ref.watch(coreRepositoryProvider);
  if (repo == null) {
    return const CoreInfo(webhookBaseUrl: '');
  }
  try {
    return await repo.getCoreInfo();
  } catch (_) {
    return const CoreInfo(webhookBaseUrl: '');
  }
}
