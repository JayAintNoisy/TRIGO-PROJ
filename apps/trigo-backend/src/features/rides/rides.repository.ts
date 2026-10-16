import { pool } from '../../shared/database/connection';
import { RideEntity, RideRating } from './rides.types';
import { RIDE_STATUS } from '../../shared/constants/ride-status';
import { PAYMENT_METHOD } from '../../shared/constants/payment-status';
import {
  parsePaymentMethodSummaries,
  withBuiltInCash,
} from '../payments/driver-payment-methods.repository';
import { v4 as uuidv4 } from 'uuid';

const RIDE_SELECT = `
  SELECT r.*,
         CONCAT_WS(' ', cu.first_name, cu.last_name) AS customer_name,
         cu.phone AS customer_phone,
         CONCAT_WS(' ', du.first_name, du.last_name) AS driver_name,
         du.phone AS driver_phone,
         m.name   AS municipality_name,
         dp.tricycle_plate_number AS tricycle_plate_number,
         dp.current_lat AS driver_lat,
         dp.current_lng AS driver_lng,
         COALESCE((
           SELECT json_agg(json_build_object('method', dpm.method, 'qrCodeUrl', dpm.qr_code_url) ORDER BY dpm.method)
           FROM driver_payment_methods dpm
           WHERE dpm.driver_profile_id = dp.id AND dpm.is_enabled = true
         ), '[]'::json) AS driver_payment_methods,
         -- Settled method, which for a completed ride is authoritative: it is
         -- written at completion and falls back to cash, whereas the ride's own
         -- payment_method is only the passenger's choice.
         (SELECT p.method FROM payments p
           WHERE p.ride_id = r.id
           ORDER BY p.created_at DESC LIMIT 1) AS settled_payment_method,
         -- One rating per ride (unique index), so these never multiply rows.
         (SELECT rr.rating FROM ride_ratings rr
           WHERE rr.ride_id = r.id LIMIT 1) AS ride_rating,
         (SELECT rr.comment FROM ride_ratings rr
           WHERE rr.ride_id = r.id LIMIT 1) AS ride_rating_comment,
         (SELECT rr.created_at FROM ride_ratings rr
           WHERE rr.ride_id = r.id LIMIT 1) AS ride_rated_at
  FROM rides r
  LEFT JOIN users cu ON cu.id = r.customer_id
  LEFT JOIN users du ON du.id = r.driver_id
  LEFT JOIN municipalities m ON m.id = r.municipality_id
  LEFT JOIN driver_profiles dp ON dp.user_id = r.driver_id
`;

export class RidesRepository {
  async findById(id: string): Promise<RideEntity | null> {
    const res = await pool.query(`${RIDE_SELECT} WHERE r.id = $1`, [id]);
    if (res.rows.length === 0) return null;
    return this.mapRowToEntity(res.rows[0]);
  }

  async findAll(filter?: { customerId?: string; driverId?: string; municipalityId?: string; status?: RIDE_STATUS }): Promise<RideEntity[]> {
    let queryText = `${RIDE_SELECT} WHERE 1=1`;
    const params: any[] = [];
    let idx = 1;

    if (filter?.customerId) {
      queryText += ` AND r.customer_id = $${idx++}`;
      params.push(filter.customerId);
    }
    if (filter?.driverId) {
      queryText += ` AND r.driver_id = $${idx++}`;
      params.push(filter.driverId);
    }
    if (filter?.municipalityId) {
      queryText += ` AND r.municipality_id = $${idx++}`;
      params.push(filter.municipalityId);
    }
    if (filter?.status) {
      queryText += ` AND r.status = $${idx++}`;
      params.push(filter.status);
    }
    queryText += ' ORDER BY r.created_at DESC';

    const res = await pool.query(queryText, params);
    return res.rows.map(this.mapRowToEntity);
  }

  async create(rideData: Omit<RideEntity, 'id' | 'createdAt' | 'updatedAt'>): Promise<RideEntity> {
    const newId = uuidv4();
    const now = new Date();
    const entity: RideEntity = {
      id: newId,
      ...rideData,
      createdAt: now,
      updatedAt: now,
    };

    await pool.query(
      `INSERT INTO rides (id, customer_id, driver_id, municipality_id, pickup_lat, pickup_lng, pickup_address, dropoff_lat, dropoff_lng, dropoff_address, status, fare_estimate, fare_final, distance_km, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)`,
      [
        entity.id,
        entity.customerId,
        entity.driverId || null,
        entity.municipalityId,
        entity.pickupLat,
        entity.pickupLng,
        entity.pickupAddress || null,
        entity.dropoffLat,
        entity.dropoffLng,
        entity.dropoffAddress || null,
        entity.status,
        entity.fareEstimate,
        entity.fareFinal || null,
        entity.distanceKm,
        entity.createdAt,
        entity.updatedAt,
      ]
    );

    return entity;
  }

  async updateStatus(
    id: string,
    status: RIDE_STATUS,
    extra?: { driverId?: string; cancellationReason?: string; cancelledBy?: 'customer' | 'driver'; fareFinal?: number; startedAt?: Date; completedAt?: Date; cancellationFee?: number }
  ): Promise<RideEntity | null> {
    await pool.query(
      `UPDATE rides SET status = $1, driver_id = COALESCE($2, driver_id), cancellation_reason = COALESCE($3, cancellation_reason), cancelled_by = COALESCE($4, cancelled_by), fare_final = COALESCE($5, fare_final), started_at = COALESCE($6, started_at), completed_at = COALESCE($7, completed_at), cancellation_fee = COALESCE($8, cancellation_fee), updated_at = NOW() WHERE id = $9`,
      [status, extra?.driverId || null, extra?.cancellationReason || null, extra?.cancelledBy || null, extra?.fareFinal || null, extra?.startedAt || null, extra?.completedAt || null, extra?.cancellationFee ?? null, id]
    );

    return this.findById(id);
  }

  /** Records the payment method the passenger chose for the ride. */
  async updatePaymentMethod(id: string, method: PAYMENT_METHOD): Promise<RideEntity | null> {
    await pool.query(
      'UPDATE rides SET payment_method = $1, updated_at = NOW() WHERE id = $2',
      [method, id]
    );

    return this.findById(id);
  }

  async findRatingByRideId(rideId: string): Promise<RideRating | null> {
    const res = await pool.query(
      'SELECT id, rating, comment, created_at FROM ride_ratings WHERE ride_id = $1 LIMIT 1',
      [rideId]
    );
    if (!res.rows[0]) return null;
    const row = res.rows[0];
    return {
      id: row.id,
      rating: row.rating,
      comment: row.comment,
      createdAt: new Date(row.created_at),
    };
  }

  async saveRating(rideId: string, customerId: string, driverId: string, rating: number, comment?: string): Promise<void> {
    await pool.query(
      'INSERT INTO ride_ratings (id, ride_id, customer_id, driver_id, rating, comment) VALUES ($1, $2, $3, $4, $5, $6)',
      [uuidv4(), rideId, customerId, driverId, rating, comment || null]
    );
  }

  /**
   * Rewrites an existing rating. Only the passenger's own rating of the driver
   * changes; the original rating time is kept so the edit window is measured
   * from the trip, not from the edit.
   */
  async updateRating(rideId: string, rating: number, comment?: string): Promise<void> {
    await pool.query(
      'UPDATE ride_ratings SET rating = $1, comment = $2 WHERE ride_id = $3',
      [rating, comment || null, rideId]
    );
  }

  private mapRowToEntity(row: any): RideEntity {
    return {
      id: row.id,
      customerId: row.customer_id,
      driverId: row.driver_id,
      municipalityId: row.municipality_id,
      pickupLat: parseFloat(row.pickup_lat),
      pickupLng: parseFloat(row.pickup_lng),
      pickupAddress: row.pickup_address,
      dropoffLat: parseFloat(row.dropoff_lat),
      dropoffLng: parseFloat(row.dropoff_lng),
      dropoffAddress: row.dropoff_address,
      status: row.status as RIDE_STATUS,
      fareEstimate: parseFloat(row.fare_estimate || 0),
      fareFinal: row.fare_final ? parseFloat(row.fare_final) : null,
      distanceKm: parseFloat(row.distance_km || 0),
      cancellationReason: row.cancellation_reason,
      cancelledBy: row.cancelled_by,
      cancellationFee: row.cancellation_fee !== null && row.cancellation_fee !== undefined ? parseFloat(row.cancellation_fee) : 0,
      startedAt: row.started_at ? new Date(row.started_at) : null,
      completedAt: row.completed_at ? new Date(row.completed_at) : null,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
      customerName: row.customer_name || undefined,
      customerPhone: row.customer_phone || undefined,
      driverName: row.driver_name || undefined,
      driverPhone: row.driver_phone || undefined,
      tricyclePlateNumber: row.tricycle_plate_number || undefined,
      municipalityName: row.municipality_name || undefined,
      driverLat: row.driver_lat !== null && row.driver_lat !== undefined
        ? parseFloat(row.driver_lat)
        : null,
      driverLng: row.driver_lng !== null && row.driver_lng !== undefined
        ? parseFloat(row.driver_lng)
        : null,
      paymentMethod: (row.payment_method as PAYMENT_METHOD) ?? null,
      settledPaymentMethod: (row.settled_payment_method as PAYMENT_METHOD) ?? null,
      rating: row.ride_rating !== null && row.ride_rating !== undefined
        ? Number(row.ride_rating)
        : null,
      ratingComment: row.ride_rating_comment ?? null,
      ratedAt: row.ride_rated_at ? new Date(row.ride_rated_at) : null,
      // No driver means nothing to pay them with yet, so the passenger has no
      // methods to choose from until the ride is accepted.
      driverPaymentMethods: row.driver_id
        ? withBuiltInCash(parsePaymentMethodSummaries(row.driver_payment_methods))
        : [],
    };
  }
}
