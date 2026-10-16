/**
 * Notification kinds written by the platform.
 *
 * Stored verbatim in `notifications.type`; the mobile app maps each id to an
 * icon, a colour and (where it makes sense) a tap destination.
 */
export const NOTIFICATION_TYPE = {
  RIDE_REQUEST: 'ride_request',
  RIDE_STARTED: 'ride_started',
  RIDE_COMPLETED: 'ride_completed',
  RIDE_CANCELLED: 'ride_cancelled',
  PAYMENT_SENT: 'payment_sent',
  PAYMENT_RECEIVED: 'payment_received',
  MESSAGE: 'message',
  ANNOUNCEMENT: 'announcement',
  SAFETY: 'safety',
} as const;

export type NotificationType =
  (typeof NOTIFICATION_TYPE)[keyof typeof NOTIFICATION_TYPE];
