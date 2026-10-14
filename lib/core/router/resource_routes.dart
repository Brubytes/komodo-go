/// Builds a detail route like `/servers/<id>?name=<name>`.
///
/// [base] is one of the `AppRoutes` collection paths.
String resourceDetailRoute(String base, String id, {String? name}) {
  final route = '$base/${Uri.encodeComponent(id)}';
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return route;
  return '$route?name=${Uri.encodeQueryComponent(trimmed)}';
}
