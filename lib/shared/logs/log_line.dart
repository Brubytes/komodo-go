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

// `docker compose logs` prefixes each line with `<name>  | `. The name is
// usually `service-1`, but a `container_name:` replaces it verbatim.
final _servicePattern = RegExp(r'^([A-Za-z0-9][\w.-]*)\s+\|\s?');

// Without a Docker timestamp after the prefix, only a replica-suffixed name
// (`redis-1`) counts, so ordinary `a | b` output is not mistaken for one.
final _replicaName = RegExp(r'-\d+$');

// Docker/Komodo timestamps, e.g. 2026-10-10T09:41:07.123456789Z.
final _timestampPattern = RegExp(
  r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})(?:[.,]\d+)?'
  r'(?:Z|[+-]\d{2}:?\d{2})?\s+',
);

// An app's own timestamp at the start of its message, e.g. Go's
// `2026/10/11 08:12:02`, Python's `2026-10-11 08:12:02,123 -`, ISO in
// brackets, or logrus' `time="2026-10-11T08:12:02Z"`.
final _echoedTimestampPattern = RegExp(
  r'^(?:\[|time=")?\d{4}[-/]\d{2}[-/]\d{2}[T ](\d{2}):(\d{2}):(\d{2})'
  r'(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2}| ?UTC)?(?:\]|")?(?:\s+[-|](?=\s))?\s+',
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
  final parts = _splitPrefix(raw);
  final time = parts.timestamp?.group(2);
  final message = time == null
      ? parts.rest
      : _stripEchoedTimestamp(parts.rest, time);
  return LogLine(
    raw: raw,
    message: message,
    service: parts.service,
    date: parts.timestamp?.group(1),
    time: time,
    severity: _severityOf(message),
  );
}

/// Splits an optional compose prefix and Docker timestamp off [line].
({String? service, RegExpMatch? timestamp, String rest}) _splitPrefix(
  String line,
) {
  final serviceMatch = _servicePattern.firstMatch(line);
  if (serviceMatch != null) {
    final afterPrefix = line.substring(serviceMatch.end);
    final timestamp = _timestampPattern.firstMatch(afterPrefix);
    final service = serviceMatch.group(1)!;
    if (timestamp != null || _replicaName.hasMatch(service)) {
      return (
        service: service,
        timestamp: timestamp,
        rest: timestamp == null
            ? afterPrefix
            : afterPrefix.substring(timestamp.end),
      );
    }
  }
  final timestamp = _timestampPattern.firstMatch(line);
  return (
    service: null,
    timestamp: timestamp,
    rest: timestamp == null ? line : line.substring(timestamp.end),
  );
}

/// Drops an app timestamp that repeats Docker's [dockerTime] (`HH:mm:ss`).
///
/// Only minutes and seconds are compared (within two seconds), so apps that
/// log in local time still match; anything else is left untouched.
String _stripEchoedTimestamp(String message, String dockerTime) {
  final match = _echoedTimestampPattern.firstMatch(message);
  if (match == null || match.end >= message.length) return message;
  int secondOfHour(String minutes, String seconds) =>
      int.parse(minutes) * 60 + int.parse(seconds);
  final docker = secondOfHour(
    dockerTime.substring(3, 5),
    dockerTime.substring(6, 8),
  );
  final echoed = secondOfHour(match.group(2)!, match.group(3)!);
  final diff = (docker - echoed).abs();
  if (diff > 2 && 3600 - diff > 2) return message;
  return message.substring(match.end);
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
String? _sortKey(String line) =>
    // Drop the trailing separator whitespace so keys compare cleanly.
    _splitPrefix(stripAnsi(line)).timestamp?.group(0)?.trimRight();

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
