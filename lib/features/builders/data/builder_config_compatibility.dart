import 'package:komodo_go/core/api/komodo_api_capabilities.dart';

/// Serializes a Server builder for the connected Core API generation.
Map<String, dynamic> serializeServerBuilderConfig({
  required Map<String, dynamic> current,
  required String serverIdsText,
  required KomodoApiCapabilities capabilities,
}) {
  final serverIds = serverIdsText
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
  final next = <String, dynamic>{...current}
    ..remove('server_id')
    ..remove('server_ids')
    ..remove('servers');

  if (capabilities.supportsMultipleServerBuilders) {
    next['server_ids'] = serverIds;
  } else {
    next['server_id'] = serverIds.isEmpty ? '' : serverIds.first;
  }
  return next;
}

/// Normalizes AWS registry fields to the connected Core API generation.
Map<String, dynamic> serializeAwsRegistryFields({
  required Map<String, dynamic> current,
  required KomodoApiCapabilities capabilities,
}) {
  final next = <String, dynamic>{...current};
  if (capabilities.supportsImageRegistryNaming) {
    if (!next.containsKey('image_registries') &&
        next.containsKey('docker_registries')) {
      next['image_registries'] = next['docker_registries'];
    }
    next.remove('docker_registries');
  } else {
    if (!next.containsKey('docker_registries') &&
        next.containsKey('image_registries')) {
      next['docker_registries'] = next['image_registries'];
    }
    next.remove('image_registries');
  }
  return next;
}
