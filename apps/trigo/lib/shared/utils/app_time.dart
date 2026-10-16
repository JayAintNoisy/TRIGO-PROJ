/// Turning the API's timestamps into what a user actually reads.
///
/// Every timestamp the backend returns is a UTC instant (ISO-8601 with a `Z`).
/// Dart parses those as UTC, so reading `.hour`, `.day` or a month off the
/// parsed value prints UTC — which is why trip and earning times looked hours
/// off. Everything that shows a time goes through this file, which converts to
/// the device's local zone first; the phone's timezone follows where the user
/// is, so a driver in the Philippines reads Philippine time.
library;

const List<String> _monthAbbreviations = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Parses a backend timestamp and converts it to local time.
///
/// Returns null for a missing or unparseable value, so callers can decide what
/// placeholder to show instead of rendering an epoch date.
DateTime? parseServerTime(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

/// Same as [parseServerTime] but also accepts values that are already a
/// [DateTime], which is what the typed repositories hand back.
DateTime? toLocalTime(dynamic value) {
  if (value is DateTime) return value.toLocal();
  return parseServerTime(value);
}

/// "12:13 PM"
String formatClock(DateTime? value, {String fallback = '—'}) {
  if (value == null) return fallback;
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

/// "Oct 16, 12:13 PM"
String formatDateTime(dynamic value, {String fallback = '—'}) {
  final local = toLocalTime(value);
  if (local == null) return fallback;
  return '${_monthAbbreviations[local.month - 1]} ${local.day}, '
      '${formatClock(local)}';
}

/// "Oct 16, 2026"
String formatDate(dynamic value, {String fallback = '—'}) {
  final local = toLocalTime(value);
  if (local == null) return fallback;
  return '${_monthAbbreviations[local.month - 1]} ${local.day}, ${local.year}';
}

/// "Just now" / "5m ago" / "3h ago" / "2d ago".
///
/// A difference between two instants does not depend on the timezone, but the
/// value still has to be parsed correctly, which [toLocalTime] guarantees.
String formatRelative(dynamic value, {DateTime? now, String fallback = ''}) {
  final local = toLocalTime(value);
  if (local == null) return fallback;
  final diff = (now ?? DateTime.now()).difference(local);
  if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Whether two instants fall on the same calendar day *where the user is*.
///
/// Used for "today's earnings": comparing UTC days would move the boundary to
/// 8am local time for a Philippine driver.
bool isSameLocalDay(dynamic a, dynamic b) {
  final first = toLocalTime(a);
  final second = toLocalTime(b);
  if (first == null || second == null) return false;
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
