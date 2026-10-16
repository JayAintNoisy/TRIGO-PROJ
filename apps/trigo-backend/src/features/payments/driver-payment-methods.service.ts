import { DriverPaymentMethodsRepository } from './driver-payment-methods.repository';
import { DriverPaymentMethodConfig } from './payments.types';
import { DriversRepository } from '../drivers/drivers.repository';
import {
  ALWAYS_ENABLED_PAYMENT_METHOD_SET,
  DRIVER_PAYMENT_METHODS,
  DRIVER_PAYMENT_METHOD_SET,
  PAYMENT_METHOD,
} from '../../shared/constants/payment-status';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';

/**
 * Driver-configurable payment methods.
 *
 * Invariant: cash is always available to every driver and is never persisted;
 * every other method is off until the driver uploads a QR code for it.
 */
export class DriverPaymentMethodsService {
  private repository = new DriverPaymentMethodsRepository();
  private driversRepository = new DriversRepository();

  /** Full catalog for the driver's own payment methods screen. */
  async getOwnPaymentMethods(userId: string): Promise<DriverPaymentMethodConfig[]> {
    const profile = await this.driversRepository.findByUserId(userId);
    if (!profile) {
      throw new AppError('Driver profile not found', 404, ERROR_CODES.NOT_FOUND);
    }

    const stored = await this.repository.findByProfileId(profile.id);
    return DRIVER_PAYMENT_METHODS.map((method) => {
      const row = stored.find((item) => item.method === method);
      return {
        method,
        isEnabled: this.isAlwaysEnabled(method) ? true : row?.isEnabled === true,
        qrCodeUrl: row?.qrCodeUrl ?? null,
      };
    });
  }

  async updateOwnPaymentMethod(
    userId: string,
    method: PAYMENT_METHOD,
    input: { isEnabled: boolean; qrCodeUrl?: string }
  ): Promise<DriverPaymentMethodConfig> {
    if (this.isAlwaysEnabled(method)) {
      throw new AppError(
        'Cash is always available and cannot be changed',
        400,
        ERROR_CODES.VALIDATION_ERROR
      );
    }
    if (!DRIVER_PAYMENT_METHOD_SET.has(method)) {
      throw new AppError('Unsupported payment method', 400, ERROR_CODES.VALIDATION_ERROR);
    }

    const profile = await this.driversRepository.findByUserId(userId);
    if (!profile) {
      throw new AppError('Driver profile not found', 404, ERROR_CODES.NOT_FOUND);
    }

    const existing = await this.repository.findByProfileAndMethod(profile.id, method);
    const qrCodeUrl = input.qrCodeUrl ?? existing?.qrCodeUrl ?? null;

    if (input.isEnabled && !qrCodeUrl) {
      throw new AppError(
        'Upload a QR code before enabling this payment method',
        400,
        ERROR_CODES.VALIDATION_ERROR
      );
    }

    const saved = await this.repository.upsert(
      profile.id,
      method,
      input.isEnabled,
      input.qrCodeUrl ?? null
    );

    return {
      method: saved.method,
      isEnabled: saved.isEnabled,
      qrCodeUrl: saved.qrCodeUrl,
    };
  }

  /** Method ids a driver accepts, cash first, for passenger-facing payloads. */
  async getEnabledMethodsByDriverUserId(driverUserId: string): Promise<PAYMENT_METHOD[]> {
    const enabled = await this.repository.findEnabledMethodsByDriverUserId(driverUserId);
    return [PAYMENT_METHOD.CASH, ...enabled.filter((method) => method !== PAYMENT_METHOD.CASH)];
  }

  isAlwaysEnabled(method: PAYMENT_METHOD): boolean {
    return ALWAYS_ENABLED_PAYMENT_METHOD_SET.has(method);
  }
}
