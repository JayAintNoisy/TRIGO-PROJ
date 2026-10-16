import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/shared/utils/app_time.dart';

/// Timestamps arrive from the API as UTC instants. Everything the user reads
/// must be converted to their local zone, which is what these cover.
void main() {
  group('parseServerTime', () {
    test('converts a UTC timestamp to local time', () {
      final parsed = parseServerTime('2026-10-16T04:13:05.811Z');

      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isFalse, reason: 'displayed times must be local');
      // The instant is unchanged; only the zone it is expressed in differs.
      expect(
        parsed.millisecondsSinceEpoch,
        DateTime.utc(2026, 10, 16, 4, 13, 5, 811).millisecondsSinceEpoch,
      );
    });

    test('accepts a DateTime as well as a string', () {
      final utc = DateTime.utc(2026, 10, 16, 4, 13, 5);
      expect(toLocalTime(utc)!.isUtc, isFalse);
      expect(toLocalTime(utc)!.millisecondsSinceEpoch, utc.millisecondsSinceEpoch);
    });

    test('returns null for missing or unusable values', () {
      expect(parseServerTime(null), isNull);
      expect(parseServerTime(''), isNull);
      expect(parseServerTime('   '), isNull);
      expect(parseServerTime('not a timestamp'), isNull);
      expect(toLocalTime(null), isNull);
    });
  });

  group('formatting', () {
    test('clock and date render the local zone, not UTC', () {
      // Built from a local wall clock, so the expectation holds in any test
      // timezone (a hardcoded +08 would fail on a UTC machine).
      final local = DateTime(2026, 10, 16, 12, 13);
      final asUtcIso = local.toUtc().toIso8601String();

      expect(formatClock(parseServerTime(asUtcIso)), '12:13 PM');
      expect(formatDateTime(asUtcIso), 'Oct 16, 12:13 PM');
      expect(formatDate(asUtcIso), 'Oct 16, 2026');
    });

    test('handles midnight and noon correctly', () {
      final midnight = DateTime(2026, 1, 2, 0, 5);
      final noon = DateTime(2026, 1, 2, 12, 0);

      expect(formatClock(midnight), '12:05 AM');
      expect(formatClock(noon), '12:00 PM');
    });

    test('falls back instead of printing an epoch date', () {
      expect(formatClock(null), '—');
      expect(formatDateTime(null), '—');
      expect(formatDateTime('garbage'), '—');
      expect(formatClock(null, fallback: ''), '');
    });
  });

  group('formatRelative', () {
    final now = DateTime(2026, 10, 16, 12, 0);

    test('counts up in minutes, hours and days', () {
      expect(formatRelative(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
      expect(formatRelative(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
      expect(formatRelative(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(formatRelative(now.subtract(const Duration(days: 2)), now: now), '2d ago');
    });

    test('does not report a future timestamp as negative age', () {
      expect(formatRelative(now.add(const Duration(minutes: 5)), now: now), 'Just now');
    });

    test('is empty for a missing value', () {
      expect(formatRelative(null, now: now), '');
    });
  });

  group('isSameLocalDay', () {
    test('compares the day where the user is, not the UTC day', () {
      // 11:30pm local is already the next day in UTC for eastern zones, and the
      // same day for western ones; either way the comparison must follow local
      // time, so a late-evening trip still counts as today.
      final lateEvening = DateTime(2026, 10, 16, 23, 30);
      final justAfterMidnight = DateTime(2026, 10, 17, 0, 30);

      expect(isSameLocalDay(lateEvening.toUtc().toIso8601String(), lateEvening), isTrue);
      expect(
        isSameLocalDay(lateEvening.toUtc().toIso8601String(), justAfterMidnight),
        isFalse,
      );
    });

    test('is false when either side is missing', () {
      expect(isSameLocalDay(null, DateTime.now()), isFalse);
      expect(isSameLocalDay(DateTime.now(), null), isFalse);
    });
  });
}
