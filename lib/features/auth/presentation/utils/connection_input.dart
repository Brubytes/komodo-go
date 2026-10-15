/// Normalizes a user-typed server URL: trims, prepends `https://` when no
/// scheme is present and strips trailing slashes.
String normalizeServerUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) return url;
  if (!url.contains('://')) {
    url = 'https://$url';
  }
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

/// Splits a pasted `key:secret` / `key secret` pair into its two parts.
///
/// Returns null unless the input clearly contains exactly two non-empty
/// tokens separated by a single colon or whitespace.
({String key, String secret})? splitKeySecret(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final parts = text.contains(':')
      ? text.split(':')
      : text.split(RegExp(r'\s+'));
  final cleaned = parts.map((p) => p.trim()).toList();
  if (cleaned.length != 2 || cleaned.any((p) => p.isEmpty)) return null;
  return (key: cleaned[0], secret: cleaned[1]);
}
