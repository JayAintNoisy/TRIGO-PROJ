import { PAYMENT_METHOD, PAYMENT_STATUS } from '../../shared/constants/payment-status';

export interface PaymentEntity {
  id: string;
  rideId: string;
  amount: number;
  method: PAYMENT_METHOD;
  status: PAYMENT_STATUS;
  createdAt: Date;
  updatedAt: Date;
}

/** A driver-configured payment method as persisted in driver_payment_methods. */
export interface DriverPaymentMethodEntity {
  id: string;
  driverProfileId: string;
  method: PAYMENT_METHOD;
  isEnabled: boolean;
  qrCodeUrl: string | null;
  createdAt: Date;
  updatedAt: Date;
}

/** Enabled payment method attached to a driver or ride payload. */
export interface DriverPaymentMethodSummary {
  method: PAYMENT_METHOD;
  qrCodeUrl: string | null;
}

/** Full configuration row shown on the driver's own payment methods screen. */
export interface DriverPaymentMethodConfig {
  method: PAYMENT_METHOD;
  isEnabled: boolean;
  qrCodeUrl: string | null;
}
