enum LogSeverity { error, warning, normal }

/// One parsed log line: an optional leading timestamp, a detected severity
/// and the remaining message, with terminal escape codes removed.
class LogLine {
  const LogLine({
    required this.raw,
    required this.message,
    this.service,
    this.date,
    this.time,
    this.severity = LogSeverity.normal,
  });

  /// The full line without escape codes, used for copying.
  final String raw;
  final String message;

  /// Compose service prefix (`redis-1` in `redis-1  | ...`), if any.
  final String? service;

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

// `docker compose logs` prefixes each line with `service-1  | `. Requiring
// the replica number keeps ordinary `a | b` output from matching.
final _servicePattern = RegExp(r'^([A-Za-z0-9][\w.-]*-\d+)\s+\|\s?');

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
  final serviceMatch = _servicePattern.firstMatch(raw);
  final rest = serviceMatch == null ? raw : raw.substring(serviceMatch.end);
  final match = _timestampPattern.firstMatch(rest);
  final message = match == null ? rest : rest.substring(match.end);
  return LogLine(
    raw: raw,
    message: message,
    service: serviceMatch?.group(1),
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

/// Sortable timestamp of a raw line (after any compose prefix), or null.
String? _sortKey(String line) {
  final serviceMatch = _servicePattern.firstMatch(line);
  final rest = serviceMatch == null ? line : line.substring(serviceMatch.end);
  final match = _timestampPattern.firstMatch(stripAnsi(rest));
  // Drop the trailing separator whitespace so keys compare cleanly.
  return match?.group(0)?.trimRight();
}

/// Merges log streams (stdout/stderr) into one chronological text.
///
/// `docker compose logs` prints one service after another and Komodo returns
/// stderr separately, so neither stream is in time order on its own. When
/// every entry carries a timestamp, entries are sorted by it (ties keep
/// their original order). Lines without a timestamp stay attached to the
/// line before them. Otherwise the streams are simply concatenated.
String mergeLogStreams(String first, String second) {
  final text = [first, second].where((part) => part.isNotEmpty).join('\n');
  if (text.isEmpty) return text;
  final records = _records(text);
  if (records.any((record) => record.key == null)) return text;
  final indexed =
      [
        for (var i = 0; i < records.length; i++) (index: i, record: records[i]),
      ]..sort((a, b) {
        final byKey = a.record.key!.compareTo(b.record.key!);
        return byKey != 0 ? byKey : a.index.compareTo(b.index);
      });
  return indexed.map((entry) => entry.record.text).join('\n');
}

/// Groups lines into records: a timestamped line plus its continuations.
List<({String? key, String text})> _records(String text) {
  final records = <({String? key, String text})>[];
  for (final line in text.split('\n')) {
    final key = _sortKey(line);
    if (key == null && records.isNotEmpty) {
      final last = records.removeLast();
      records.add((key: last.key, text: '${last.text}\n$line'));
    } else {
      records.add((key: key, text: line));
    }
  }
  return records;
}
