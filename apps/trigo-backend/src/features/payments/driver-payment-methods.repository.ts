import { pool } from '../../shared/database/connection';
import { DriverPaymentMethodEntity, DriverPaymentMethodSummary } from './payments.types';
import { PAYMENT_METHOD } from '../../shared/constants/payment-status';
import { v4 as uuidv4 } from 'uuid';

/**
 * Parses the `json_agg` column used by the driver and ride selects into
 * payment method summaries. Unknown shapes degrade to an empty list.
 */
export function parsePaymentMethodSummaries(value: unknown): DriverPaymentMethodSummary[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((row) => row && typeof row.method === 'string')
    .map((row) => ({
      method: row.method as PAYMENT_METHOD,
      qrCodeUrl: typeof row.qrCodeUrl === 'string' ? row.qrCodeUrl : null,
    }));
}

/**
 * Adds the always-available cash method to a passenger-facing list.
 *
 * Cash is never stored per driver, so it is prepended wherever enabled methods
 * are reported to passengers.
 */
export function withBuiltInCash(
  methods: DriverPaymentMethodSummary[]
): DriverPaymentMethodSummary[] {
  return [
    { method: PAYMENT_METHOD.CASH, qrCodeUrl: null },
    ...methods.filter((item) => item.method !== PAYMENT_METHOD.CASH),
  ];
}

/**
 * Persistence for the per-driver payment methods a driver has switched on.
 *
 * Only non-cash methods are ever stored: cash is available to every driver and
 * is never written to this table.
 */
export class DriverPaymentMethodsRepository {
  async findByProfileId(driverProfileId: string): Promise<DriverPaymentMethodEntity[]> {
    const res = await pool.query(
      'SELECT * FROM driver_payment_methods WHERE driver_profile_id = $1 ORDER BY method ASC',
      [driverProfileId]
    );
    return res.rows.map(this.mapRowToEntity);
  }

  async findByProfileAndMethod(
    driverProfileId: string,
    method: PAYMENT_METHOD
  ): Promise<DriverPaymentMethodEntity | null> {
    const res = await pool.query(
      'SELECT * FROM driver_payment_methods WHERE driver_profile_id = $1 AND method = $2',
      [driverProfileId, method]
    );
    if (res.rows.length === 0) return null;
    return this.mapRowToEntity(res.rows[0]);
  }

  /**
   * Creates or updates a method. A null [qrCodeUrl] keeps the stored QR so
   * switching a method off never forces a re-upload to switch it back on.
   */
  async upsert(
    driverProfileId: string,
    method: PAYMENT_METHOD,
    isEnabled: boolean,
    qrCodeUrl?: string | null
  ): Promise<DriverPaymentMethodEntity> {
    const res = await pool.query(
      `INSERT INTO driver_payment_methods (id, driver_profile_id, method, is_enabled, qr_code_url, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
       ON CONFLICT (driver_profile_id, method)
       DO UPDATE SET is_enabled = EXCLUDED.is_enabled,
                     qr_code_url = COALESCE($5, driver_payment_methods.qr_code_url),
                     updated_at = NOW()
       RETURNING *`,
      [uuidv4(), driverProfileId, method, isEnabled, qrCodeUrl ?? null]
    );
    return this.mapRowToEntity(res.rows[0]);
  }

  /** Enabled non-cash methods for one driver, keyed by the driver's user id. */
  async findEnabledMethodsByDriverUserId(driverUserId: string): Promise<PAYMENT_METHOD[]> {
    const res = await pool.query(
      `SELECT dpm.method
       FROM driver_payment_methods dpm
       JOIN driver_profiles dp ON dp.id = dpm.driver_profile_id
       WHERE dp.user_id = $1 AND dpm.is_enabled = true`,
      [driverUserId]
    );
    return res.rows.map((row) => row.method as PAYMENT_METHOD);
  }

  private mapRowToEntity(row: any): DriverPaymentMethodEntity {
    return {
      id: row.id,
      driverProfileId: row.driver_profile_id,
      method: row.method as PAYMENT_METHOD,
      isEnabled: row.is_enabled === true,
      qrCodeUrl: row.qr_code_url ?? null,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}
