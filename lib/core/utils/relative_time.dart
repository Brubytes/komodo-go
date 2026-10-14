/// Komodo timestamps are usually epoch milliseconds, but a few payloads use
/// seconds. Values below 1e12 (~2001 in ms) are treated as seconds.
DateTime komodoTimestamp(int unix) => DateTime.fromMillisecondsSinceEpoch(
  unix < 1000000000000 ? unix * 1000 : unix,
);

/// "5m ago", "3h ago", "2d ago" or "just now".
String formatTimeAgo(int unix, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(komodoTimestamp(unix));
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'just now';
}

/// "in 5m", "in 3h", "in 2d", "in <1m" or "overdue".
String formatTimeUntil(int unix, {DateTime? now}) {
  final diff = komodoTimestamp(unix).difference(now ?? DateTime.now());
  if (diff.inDays > 0) return 'in ${diff.inDays}d';
  if (diff.inHours > 0) return 'in ${diff.inHours}h';
  if (diff.inMinutes > 0) return 'in ${diff.inMinutes}m';
  return diff.isNegative ? 'overdue' : 'in <1m';
}
