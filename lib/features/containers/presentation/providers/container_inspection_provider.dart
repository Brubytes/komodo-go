import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/data/repositories/container_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'container_inspection_provider.g.dart';

@riverpod
Future<ContainerInspection?> containerInspection(
  Ref ref, {
  required String serverIdOrName,
  required String containerIdOrName,
}) async {
  final repository = ref.watch(containerRepositoryProvider);
  if (repository == null) return null;
  return unwrapOrThrow(
    await repository.inspectContainer(
      serverIdOrName: serverIdOrName,
      containerIdOrName: containerIdOrName,
    ),
  );
}

@riverpod
Future<ContainerAssociatedResource?> containerAssociatedResource(
  Ref ref, {
  required String serverIdOrName,
  required String containerIdOrName,
}) async {
  final repository = ref.watch(containerRepositoryProvider);
  if (repository == null) return null;
  return unwrapOrThrow(
    await repository.getResourceMatchingContainer(
      serverIdOrName: serverIdOrName,
      containerIdOrName: containerIdOrName,
    ),
  );
}
