/// How long a passenger may change a rating they already gave.
///
/// Kept in step with the backend's `RATING_EDIT_WINDOW_HOURS`. Ride-hailing
/// apps are conservative about this: Lyft gives a rider a short window (at
/// least 2 hours) to rate at all and routes a mistaken rating to support rather
/// than allowing a self-service edit, and Uber documents rating changes only
/// for drivers changing a rider's rating. Review systems that do allow edits
/// bound them by a window, so editing here is allowed but time-limited, after
/// which the rating is locked.
const Duration ratingEditWindow = Duration(hours: 24);

/// Whether a rating made against a trip completed at [completedAt] may still be
/// changed. A trip with no completion time is never editable.
///
/// The deadline itself is included, matching the backend's comparison, so the
/// app never offers an edit the API would then refuse.
bool isRatingEditable(DateTime? completedAt, {DateTime? now}) {
  if (completedAt == null) return false;
  final moment = now ?? DateTime.now();
  return !moment.isAfter(completedAt.add(ratingEditWindow));
}

/// How long is left of the edit window, or null once it has closed.
Duration? ratingEditTimeLeft(DateTime? completedAt, {DateTime? now}) {
  if (completedAt == null) return null;
  final moment = now ?? DateTime.now();
  final closesAt = completedAt.add(ratingEditWindow);
  if (moment.isAfter(closesAt)) return null;
  final left = closesAt.difference(moment);
  return left.isNegative ? Duration.zero : left;
}

/// Human phrasing for the window, e.g. "24 hours", for user-facing copy.
String ratingEditWindowLabel() {
  final hours = ratingEditWindow.inHours;
  if (hours > 0) return '$hours hours';
  return '${ratingEditWindow.inMinutes} minutes';
}
