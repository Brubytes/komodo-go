import 'package:komodo_go/core/data/models/core_info.dart';
import 'package:komodo_go/core/data/repositories/core_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'core_info_provider.g.dart';

@riverpod
Future<CoreInfo> coreInfo(Ref ref) async {
  final repo = ref.watch(coreRepositoryProvider);
  if (repo == null) {
    return const CoreInfo(webhookBaseUrl: '');
  }
  try {
    return await repo.getCoreInfo();
  } on Exception {
    return const CoreInfo(webhookBaseUrl: '');
  }
}
