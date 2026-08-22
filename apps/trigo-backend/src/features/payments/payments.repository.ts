import { pool } from '../../shared/database/connection';
import { PaymentEntity } from './payments.types';
import { PAYMENT_METHOD, PAYMENT_STATUS } from '../../shared/constants/payment-status';
import { v4 as uuidv4 } from 'uuid';

export class PaymentsRepository {
  async create(
    rideId: string,
    amount: number,
    method: PAYMENT_METHOD = PAYMENT_METHOD.CASH,
    status: PAYMENT_STATUS = PAYMENT_STATUS.COMPLETED
  ): Promise<PaymentEntity> {
    const newId = uuidv4();
    const now = new Date();

    await pool.query(
      `INSERT INTO payments (id, ride_id, amount, method, status, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [newId, rideId, amount, method, status, now, now]
    );

    const created = await this.findById(newId);
    return created!;
  }

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
