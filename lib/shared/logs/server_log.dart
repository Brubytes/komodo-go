class ServerLogSnapshot {
  const ServerLogSnapshot({
    this.stage = '',
    this.command = '',
    this.stdout = '',
    this.stderr = '',
    this.success = false,
    this.startTs = 0,
    this.endTs = 0,
    this.truncated = false,
  });

  factory ServerLogSnapshot.fromJson(Map<String, dynamic> json) {
    return ServerLogSnapshot(
      stage: json['stage']?.toString() ?? '',
      command: json['command']?.toString() ?? '',
      stdout: json['stdout']?.toString() ?? '',
      stderr: json['stderr']?.toString() ?? '',
      success: json['success'] == true,
      startTs: (json['start_ts'] as num?)?.toInt() ?? 0,
      endTs: (json['end_ts'] as num?)?.toInt() ?? 0,
    );
  }

  final String stage;
  final String command;
  final String stdout;
  final String stderr;
  final bool success;
  final int startTs;
  final int endTs;
  final bool truncated;

  String get combined {
    final output = [
      if (stdout.trim().isNotEmpty) stdout.trim(),
      if (stderr.trim().isNotEmpty) stderr.trim(),
    ].join('\n');
    if (!truncated) return output;
    return [
      '[Output truncated to the selected tail limit]',
      if (output.isNotEmpty) output,
    ].join('\n');
  }

  /// Caps eagerly-rendered log output before it reaches Flutter's text layout.
  ///
  /// Komodo's search endpoints do not accept a tail argument, so a broad
  /// server-side match can otherwise return substantially more output than the
  /// selected tail count suggests.
  ServerLogSnapshot capped({required int tail, int maxCharacters = 250000}) {
    final cappedStdout = _capLogText(
      stdout,
      maxLines: tail,
      maxCharacters: maxCharacters,
    );
    final cappedStderr = _capLogText(
      stderr,
      maxLines: tail,
      maxCharacters: maxCharacters,
    );
    return ServerLogSnapshot(
      stage: stage,
      command: command,
      stdout: cappedStdout.text,
      stderr: cappedStderr.text,
      success: success,
      startTs: startTs,
      endTs: endTs,
      truncated: truncated || cappedStdout.truncated || cappedStderr.truncated,
    );
  }
}

({String text, bool truncated}) _capLogText(
  String input, {
  required int maxLines,
  required int maxCharacters,
}) {
  if (input.isEmpty) return (text: input, truncated: false);

  var start = 0;
  var lines = 1;
  for (var index = input.length - 1; index >= 0; index--) {
    if (input.codeUnitAt(index) != 10 || index == input.length - 1) continue;
    lines += 1;
    if (lines > maxLines) {
      start = index + 1;
      break;
    }
  }

  if (input.length - start > maxCharacters) {
    start = input.length - maxCharacters;
    final nextNewline = input.indexOf('\n', start);
    if (nextNewline >= 0 && nextNewline < input.length - 1) {
      start = nextNewline + 1;
    }
  }

  return (text: input.substring(start), truncated: start > 0);
}

enum LogSearchCombinator {
  and('And'),
  or('Or');

  const LogSearchCombinator(this.apiValue);

  /// Komodo's Rust enum uses its case-sensitive variant names on the wire.
  final String apiValue;
}

class ServerLogRequest {
  const ServerLogRequest({
    this.terms = const [],
    this.combinator = LogSearchCombinator.and,
    this.invert = false,
    this.tail = 200,
    this.timestamps = true,
  });

  final List<String> terms;
  final LogSearchCombinator combinator;
  final bool invert;
  final int tail;
  final bool timestamps;

  bool get isSearch => terms.isNotEmpty;
}

class SavedLogFilter {
  const SavedLogFilter({
    required this.name,
    required this.terms,
    required this.combinator,
    required this.invert,
    required this.timestamps,
  });

  factory SavedLogFilter.fromJson(Map<String, dynamic> json) {
    return SavedLogFilter(
      name: json['name']?.toString() ?? '',
      terms: (json['terms'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      combinator: json['combinator'] == 'or'
          ? LogSearchCombinator.or
          : LogSearchCombinator.and,
      invert: json['invert'] == true,
      timestamps: json['timestamps'] != false,
    );
  }

  final String name;
  final List<String> terms;
  final LogSearchCombinator combinator;
  final bool invert;
  final bool timestamps;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'terms': terms,
    'combinator': combinator.name,
    'invert': invert,
    'timestamps': timestamps,
  };
}
