const int variableNameMaxLength = 500;

final RegExp _variableNamePattern = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

/// Returns a user-facing validation message for Komodo v2.3 variable names.
String? validateVariableName(String value) {
  final name = value.trim();
  if (name.isEmpty) return 'Enter a variable name.';
  if (name.length > variableNameMaxLength) {
    return 'Variable names can contain at most $variableNameMaxLength characters.';
  }
  if (!_variableNamePattern.hasMatch(name)) {
    return 'Use letters, numbers, and underscores; start with a letter or underscore.';
  }
  return null;
}
