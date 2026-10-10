import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/shared/logs/log_line.dart';

void main() {
  group('parseLogLine', () {
    test('splits docker timestamps into date, time and message', () {
      final line = parseLogLine(
        '2026-10-10T09:41:07.123456789Z  INFO  GET /health 200',
      );
      expect(line.date, '2026-10-10');
      expect(line.time, '09:41:07');
      expect(line.message, 'INFO  GET /health 200');
      expect(line.severity, LogSeverity.normal);
    });

    test('keeps lines without timestamps intact', () {
      final line = parseLogLine('plain output');
      expect(line.time, isNull);
      expect(line.message, 'plain output');
    });

    test('detects severity from level markers near the start', () {
      expect(parseLogLine('ERROR boom').severity, LogSeverity.error);
      expect(parseLogLine('level=fatal msg=x').severity, LogSeverity.error);
      expect(parseLogLine('[warn] slow').severity, LogSeverity.warning);
      expect(parseLogLine('INFO terror').severity, LogSeverity.normal);
      final longInfo = 'INFO ${'x' * 100} error later';
      expect(parseLogLine(longInfo).severity, LogSeverity.normal);
    });

    test('strips ANSI colour codes and carriage returns', () {
      final line = parseLogLine('\x1B[32mINFO\x1B[0m ready\r');
      expect(line.raw, 'INFO ready');
      expect(line.message, 'INFO ready');
    });
  });

  test('parseLogEntries inserts a divider per new date', () {
    final entries = parseLogEntries(
      [
        '2026-10-09T23:59:59Z a',
        '2026-10-09T23:59:59Z b',
        'continuation',
        '2026-10-10T00:00:01Z c',
      ].join('\n'),
    );
    expect(entries.map((e) => e.runtimeType), [
      LogDateDivider,
      LogLineEntry,
      LogLineEntry,
      LogLineEntry,
      LogDateDivider,
      LogLineEntry,
    ]);
    expect((entries[4] as LogDateDivider).date, '2026-10-10');
  });
}
