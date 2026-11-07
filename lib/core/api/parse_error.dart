import 'package:json_annotation/json_annotation.dart';
import 'package:komodo_go/core/error/failures.dart';

/// Returns true when [error] looks like a response-shape problem raised while
/// decoding JSON (checked json_serializable errors or plain cast errors).
bool isParseError(Object error) =>
    error is CheckedFromJsonException || error is TypeError;

/// Builds a field path like `KomodoStack.config → StackConfig.additional_env_files`
/// from a (possibly nested) [CheckedFromJsonException]. json_serializable
/// rethrows nested errors unchanged, so usually only the innermost
/// `Class.key` is known; wrapped `innerError` chains are still unwrapped.
/// Returns null when no path information is available.
String? parseErrorPath(Object error) {
  final segments = <String>[];
  Object? current = error;
  while (current is CheckedFromJsonException) {
    // Freezed implementation classes are private (`_StackConfig`).
    final className = current.className?.replaceFirst(RegExp(r'^[_$]+'), '');
    final key = current.key;
    if (className != null && key != null) {
      segments.add('$className.$key');
    } else if (key != null) {
      segments.add(key);
    } else if (className != null) {
      segments.add(className);
    }
    current = current.innerError;
  }
  if (segments.isEmpty) return null;
  return segments.join(' → ');
}

/// Maps a decoding error to [ParseFailure], or null if [error] is not one.
ParseFailure? parseFailureFrom(Object error) {
  if (!isParseError(error)) return null;
  return ParseFailure(path: parseErrorPath(error));
}
