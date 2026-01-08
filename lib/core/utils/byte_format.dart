String formatBytes(num bytes, {int fractionDigits = 1}) {
  final value = bytes.toDouble();
  if (value.isNaN || value.isInfinite) return '—';
  if (value.abs() < 1024) return '${value.toStringAsFixed(0)} B';

  const units = ['KB', 'MB', 'GB', 'TB', 'PB'];
  var unitIndex = 0;
  var current = value / 1024;
  while (current.abs() >= 1024 && unitIndex < units.length - 1) {
    current /= 1024;
    unitIndex++;
  }

  return '${current.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}

String formatBytesPerSecond(num bytesPerSecond, {int fractionDigits = 1}) =>
    '${formatBytes(bytesPerSecond, fractionDigits: fractionDigits)}/s';
