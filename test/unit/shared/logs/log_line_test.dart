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

  group('compose output', () {
    test('splits the service prefix before the timestamp', () {
      final line = parseLogLine(
        'redis-1  | 2026-10-10T17:41:46.322188048Z 1:M Ready to accept',
      );
      expect(line.service, 'redis-1');
      expect(line.time, '17:41:46');
      expect(line.message, '1:M Ready to accept');
    });

    test('ignores pipes that are not compose prefixes', () {
      final line = parseLogLine('cat file | grep error');
      expect(line.service, isNull);
      expect(line.message, 'cat file | grep error');
    });
  });

  group('mergeLogStreams', () {
    test('interleaves stdout and stderr by timestamp', () {
      const stdout =
          '2026-10-10T17:41:47.000000000Z GET / 200\n'
          '2026-10-10T17:42:04.000000000Z GET / 200';
      const stderr =
          '2026-10-10T17:41:46.000000000Z [notice] start\n'
          '2026-10-10T17:41:48.000000000Z [notice] worker';
      expect(mergeLogStreams(stdout, stderr).split('\n'), [
        '2026-10-10T17:41:46.000000000Z [notice] start',
        '2026-10-10T17:41:47.000000000Z GET / 200',
        '2026-10-10T17:41:48.000000000Z [notice] worker',
        '2026-10-10T17:42:04.000000000Z GET / 200',
      ]);
    });

    test('keeps continuation lines with their entry', () {
      const stdout = '2026-10-10T10:00:02Z b';
      const stderr =
          '2026-10-10T10:00:01Z a\n  at frame\n2026-10-10T10:00:03Z c';
      expect(mergeLogStreams(stdout, stderr).split('\n'), [
        '2026-10-10T10:00:01Z a',
        '  at frame',
        '2026-10-10T10:00:02Z b',
        '2026-10-10T10:00:03Z c',
      ]);
    });

    test('orders compose output that is grouped per service', () {
      const stdout =
          'web-1  | 2026-10-10T17:47:01Z b\n'
          'redis-1  | 2026-10-10T17:41:46Z a';
      expect(
        mergeLogStreams(stdout, ''),
        'redis-1  | 2026-10-10T17:41:46Z a\nweb-1  | 2026-10-10T17:47:01Z b',
      );
    });

    test('concatenates streams without timestamps', () {
      expect(mergeLogStreams('out', 'err'), 'out\nerr');
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
