import 'package:komodo_go/core/api/parse_error.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/utils/debug_log.dart';

/// Parses every entry of [json] separately so one malformed item cannot fail
/// the whole list.
///
/// Bad items are skipped and logged (error plus the item's id/name only, never
/// the payload). When the list is non-empty and *every* item fails, the
/// readable [ParseFailure] of the first item is thrown rather than returning
/// an empty list.
List<T> parseListLenient<T>(
  Iterable<dynamic> json,
  T Function(Map<String, dynamic> json) fromJson, {
  required String label,
}) {
  final result = <T>[];
  ParseFailure? firstFailure;
  var total = 0;

  for (final item in json) {
    total += 1;
    try {
      if (item is! Map) {
        throw TypeError();
      }
      result.add(fromJson(Map<String, dynamic>.from(item)));
    } on Object catch (e) {
      final failure = parseFailureFrom(e);
      if (failure == null) rethrow;
      firstFailure ??= failure;
      debugLog(
        'Skipping unreadable $label item ${_describeItem(item)}'
        '${failure.path != null ? ' (${failure.path})' : ''}',
        name: 'API',
        error: e,
      );
    }
  }

  if (total > 0 && result.isEmpty && firstFailure != null) {
    // Failure is handled by apiCall, which returns thrown failures as-is.
    // ignore: only_throw_errors
    throw firstFailure;
  }
  return result;
}

String _describeItem(dynamic item) {
  if (item is! Map) return '(not an object)';
  final name = item['name'];
  if (name is String && name.isNotEmpty) return 'name=$name';
  final id = item['id'] ?? item['_id'];
  if (id is String) return 'id=$id';
  if (id is Map && id[r'$oid'] is String) return 'id=${id[r'$oid']}';
  return '(unidentified)';
}
