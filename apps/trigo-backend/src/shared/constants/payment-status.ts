export enum PAYMENT_METHOD {
  CASH = 'cash',
  GCASH = 'gcash',
  MAYA = 'maya',
  GOTYME = 'gotyme',
  MARIBANK = 'maribank',
  /** Legacy method, no longer offered in the mobile app. */
  CARD = 'card',
}

export enum PAYMENT_STATUS {
  PENDING = 'pending',
  COMPLETED = 'completed',
  REFUNDED = 'refunded',
}

/**
 * Payment methods a driver can configure, in display order.
 *
 * Cash is always available and is never stored per driver; every other method
 * is off until the driver uploads a QR code for it.
 */
export const DRIVER_PAYMENT_METHODS = [
  PAYMENT_METHOD.CASH,
  PAYMENT_METHOD.GCASH,
  PAYMENT_METHOD.MAYA,
  PAYMENT_METHOD.GOTYME,
  PAYMENT_METHOD.MARIBANK,
] as const;

/** The literal union of configurable method ids. */
export type DriverPaymentMethod = (typeof DRIVER_PAYMENT_METHODS)[number];

/** Methods that are enabled for every driver without configuration. */
export const ALWAYS_ENABLED_PAYMENT_METHODS = [PAYMENT_METHOD.CASH] as const;

export const DRIVER_PAYMENT_METHOD_SET: ReadonlySet<PAYMENT_METHOD> = new Set(
  DRIVER_PAYMENT_METHODS
);

export const ALWAYS_ENABLED_PAYMENT_METHOD_SET: ReadonlySet<PAYMENT_METHOD> = new Set(
  ALWAYS_ENABLED_PAYMENT_METHODS
);

/** Human-readable names used in notification and message copy. */
export const PAYMENT_METHOD_LABELS: Record<string, string> = {
  [PAYMENT_METHOD.CASH]: 'Cash',
  [PAYMENT_METHOD.GCASH]: 'GCash',
  [PAYMENT_METHOD.MAYA]: 'Maya',
  [PAYMENT_METHOD.GOTYME]: 'GoTyme',
  [PAYMENT_METHOD.MARIBANK]: 'Maribank',
  [PAYMENT_METHOD.CARD]: 'Card',
};

export function paymentMethodLabel(method: string): string {
  return PAYMENT_METHOD_LABELS[method] ?? method;
}
