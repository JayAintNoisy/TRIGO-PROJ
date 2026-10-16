/**
 * How long a passenger may change a rating they already gave.
 *
 * Ride-hailing apps are conservative here: Lyft gives a rider a short window
 * (at least 2 hours) to rate at all and routes a mistaken rating to support
 * rather than allowing a self-service edit, and Uber documents rating changes
 * only for drivers changing a rider's rating. Review systems that do allow
 * edits (marketplaces) bound them by a window.
 *
 * So editing is allowed, but only for a bounded period after the trip, after
 * which the rating is locked and read-only. Raise this constant if a longer
 * grace period is wanted — the app renders the same window from its own copy of
 * the duration.
 */
export const RATING_EDIT_WINDOW_HOURS = 24;

/**
 * Whether a rating made against a trip completed at [completedAt] may still be
 * changed, as of [now]. A trip with no completion time is never editable.
 */
export function isWithinRatingEditWindow(
  completedAt: Date | null | undefined,
  now: Date = new Date()
): boolean {
  if (!completedAt) return false;
  const closesAt = new Date(completedAt.getTime() + RATING_EDIT_WINDOW_HOURS * 60 * 60 * 1000);
  return now.getTime() <= closesAt.getTime();
}
