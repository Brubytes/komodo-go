enum LogSeverity { error, warning, normal }

/// One parsed log line: an optional leading timestamp, a detected severity
/// and the remaining message, with terminal escape codes removed.
class LogLine {
  const LogLine({
    required this.raw,
    required this.message,
    this.date,
    this.time,
    this.severity = LogSeverity.normal,
  });

  /// The full line without escape codes, used for copying.
  final String raw;
  final String message;

  /// `yyyy-MM-dd` part of a leading ISO timestamp, if any.
  final String? date;

  /// `HH:mm:ss` part of a leading ISO timestamp, if any.
  final String? time;
  final LogSeverity severity;
}

/// Either a date divider or a log line, in display order.
sealed class LogEntry {
  const LogEntry();
}

class LogDateDivider extends LogEntry {
  const LogDateDivider(this.date);

  final String date;
}

class LogLineEntry extends LogEntry {
  const LogLineEntry(this.line);

  final LogLine line;
}

// CSI sequences (colours, cursor moves) and OSC sequences (titles, links).
final _ansiPattern = RegExp(
  r'\x1B(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1B]*(?:\x07|\x1B\\)|[@-Z\\-_])',
);

// Docker/Komodo timestamps, e.g. 2026-10-10T09:41:07.123456789Z.
final _timestampPattern = RegExp(
  r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})(?:[.,]\d+)?'
  r'(?:Z|[+-]\d{2}:?\d{2})?\s+',
);

final _errorPattern = RegExp(
  r'\b(?:error|err|fatal|crit|critical|panic|emerg|alert|exception)\b',
  caseSensitive: false,
);
final _warningPattern = RegExp(r'\b(?:warn|warning)\b', caseSensitive: false);

String stripAnsi(String input) =>
    input.contains('\x1B') ? input.replaceAll(_ansiPattern, '') : input;

LogLine parseLogLine(String input) {
  final raw = stripAnsi(input).replaceAll('\r', '');
  final match = _timestampPattern.firstMatch(raw);
  final message = match == null ? raw : raw.substring(match.end);
  return LogLine(
    raw: raw,
    message: message,
    date: match?.group(1),
    time: match?.group(2),
    severity: _severityOf(message),
  );
}

LogSeverity _severityOf(String message) {
  // Only the start of the message, where level markers live, so a request
  // path like /errors/ further along doesn't flag an info line.
  final head = message.length > 80 ? message.substring(0, 80) : message;
  if (_errorPattern.hasMatch(head)) return LogSeverity.error;
  if (_warningPattern.hasMatch(head)) return LogSeverity.warning;
  return LogSeverity.normal;
}

/// Parses [text] into display entries, inserting a date divider before the
/// first line of each new day.
List<LogEntry> parseLogEntries(String text) {
  if (text.isEmpty) return const [];
  final entries = <LogEntry>[];
  String? currentDate;
  for (final rawLine in text.split('\n')) {
    final line = parseLogLine(rawLine);
    final date = line.date;
    if (date != null && date != currentDate) {
      entries.add(LogDateDivider(date));
      currentDate = date;
    }
    entries.add(LogLineEntry(line));
  }
  return entries;
}
