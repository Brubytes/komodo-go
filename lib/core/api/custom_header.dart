import 'package:flutter/foundation.dart';

const reservedManagedHeaderNames = <String>{
  'authorization',
  'x-api-key',
  'x-api-secret',
};

bool isReservedManagedHeaderName(String name) {
  return reservedManagedHeaderNames.contains(name.trim().toLowerCase());
}

@immutable
class CustomHeader {
  const CustomHeader({required this.key, required this.value});

  final String key;
  final String value;

  String get trimmedKey => key.trim();
  String get trimmedValue => value.trim();
  bool get hasKey => trimmedKey.isNotEmpty;
  bool get isBlank => trimmedKey.isEmpty && trimmedValue.isEmpty;
  bool get isReserved => isReservedManagedHeaderName(trimmedKey);

  CustomHeader copyWith({String? key, String? value}) {
    return CustomHeader(
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  CustomHeader normalized() {
    return CustomHeader(key: trimmedKey, value: trimmedValue);
  }

  Map<String, dynamic> toJson() {
    final normalized = this.normalized();
    return <String, dynamic>{
      'key': normalized.key,
      'value': normalized.value,
    };
  }

  static CustomHeader fromJson(Map<String, dynamic> json) {
    return CustomHeader(
      key: (json['key'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
    );
  }
}

List<CustomHeader> sanitizeCustomHeaders(Iterable<CustomHeader> headers) {
  final sanitized = <CustomHeader>[];
  final indexByKey = <String, int>{};

  for (final header in headers) {
    final normalized = header.normalized();
    if (!normalized.hasKey || normalized.isReserved) {
      continue;
    }

    final normalizedKey = normalized.trimmedKey.toLowerCase();
    final existingIndex = indexByKey[normalizedKey];
    if (existingIndex != null) {
      sanitized[existingIndex] = normalized;
      continue;
    }

    indexByKey[normalizedKey] = sanitized.length;
    sanitized.add(normalized);
  }

  return sanitized;
}
