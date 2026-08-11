import 'package:flutter/foundation.dart';

import 'package:komodo_go/shared/resources/models/resource_kind.dart';

@immutable
class ResourceMetadata {
  const ResourceMetadata({
    required this.kind,
    required this.id,
    required this.name,
    required this.description,
    required this.template,
    required this.tags,
  });

  final ResourceKind kind;
  final String id;
  final String name;
  final String description;
  final bool template;
  final List<String> tags;
}

@immutable
class ResourceMetadataDraft {
  const ResourceMetadataDraft({
    required this.description,
    required this.template,
    required this.tags,
  });

  final String description;
  final bool template;
  final List<String> tags;
}
