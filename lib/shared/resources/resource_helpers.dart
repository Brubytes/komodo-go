import 'package:flutter/material.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';

typedef ResourceNameResolver = Future<String> Function(ResourceRef ref);

IconData resourceIcon(ResourceKind kind) => kind.icon;

IconData resourceIconForVariant(String variant) {
  return ResourceKindX.fromVariant(variant).icon;
}

String resourceLabel({
  required ResourceRef ref,
  required Map<String, String> lookup,
  String? directName,
}) {
  final direct = directName?.trim();
  if (direct != null && direct.isNotEmpty) return direct;

  final lookupName = lookup[ref.key];
  if (lookupName != null && lookupName.trim().isNotEmpty) {
    return lookupName.trim();
  }

  return '${ref.kind.variant} ${_shortId(ref.normalizedId)}';
}

String _shortId(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 10) return trimmed;
  final start = trimmed.substring(0, 6);
  final end = trimmed.substring(trimmed.length - 4);
  return '$start...$end';
}
