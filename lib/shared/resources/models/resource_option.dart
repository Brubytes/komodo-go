import 'package:flutter/material.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';

class ResourceOption {
  const ResourceOption({required this.ref, required this.name});

  final ResourceRef ref;
  final String name;

  String get variant => ref.kind.variant;
  String get key => ref.key;
  IconData get icon => ref.kind.icon;
}
