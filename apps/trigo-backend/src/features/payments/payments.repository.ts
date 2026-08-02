import { pool } from '../../shared/database/connection';
import { PaymentEntity } from './payments.types';
import { PAYMENT_METHOD, PAYMENT_STATUS } from '../../shared/constants/payment-status';

export class PaymentsRepository {
  async findAll(): Promise<PaymentEntity[]> {
    const res = await pool.query('SELECT * FROM payments ORDER BY created_at DESC');
    return res.rows.map(this.mapRowToEntity);
  }

  async findById(id: string): Promise<PaymentEntity | null> {
    const res = await pool.query('SELECT * FROM payments WHERE id = $1', [id]);
    if (res.rows.length === 0) return null;
    return this.mapRowToEntity(res.rows[0]);
  }

  async findByRideId(rideId: string): Promise<PaymentEntity | null> {
    const res = await pool.query('SELECT * FROM payments WHERE ride_id = $1', [rideId]);
    if (res.rows.length === 0) return null;
    return this.mapRowToEntity(res.rows[0]);
  }

  private mapRowToEntity(row: any): PaymentEntity {
    return {
      id: row.id,
      rideId: row.ride_id,
      amount: parseFloat(row.amount),
      method: row.method as PAYMENT_METHOD,
      status: row.status as PAYMENT_STATUS,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}
