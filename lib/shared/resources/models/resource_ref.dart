import 'package:flutter/foundation.dart';

import 'package:komodo_go/shared/resources/models/resource_kind.dart';

@immutable
class ResourceRef {
  const ResourceRef({required this.kind, required this.id});

  final ResourceKind kind;
  final String id;

  String get normalizedId => id.trim();

  String get key => '${kind.variant.toLowerCase()}:$normalizedId';

  static ResourceRef? tryParseKey(String value) {
    final index = value.indexOf(':');
    if (index <= 0 || index == value.length - 1) return null;
    final variant = value.substring(0, index);
    final id = value.substring(index + 1).trim();
    if (id.isEmpty) return null;
    return ResourceRef(kind: ResourceKindX.fromVariant(variant), id: id);
  }

  @override
  bool operator ==(Object other) {
    return other is ResourceRef &&
        other.kind == kind &&
        other.normalizedId == normalizedId;
  }

  @override
  int get hashCode => Object.hash(kind, normalizedId);

  @override
  String toString() => key;
}
