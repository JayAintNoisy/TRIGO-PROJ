import { pool } from '../../shared/database/connection';
import { RideEntity } from './rides.types';
import { RIDE_STATUS } from '../../shared/constants/ride-status';
import { v4 as uuidv4 } from 'uuid';

export class RidesRepository {
  async findById(id: string): Promise<RideEntity | null> {
    const res = await pool.query('SELECT * FROM rides WHERE id = $1', [id]);
    if (res.rows.length === 0) return null;
    return this.mapRowToEntity(res.rows[0]);
  }

  async findAll(filter?: { customerId?: string; driverId?: string; status?: RIDE_STATUS }): Promise<RideEntity[]> {
    let queryText = 'SELECT * FROM rides WHERE 1=1';
    const params: any[] = [];
    let idx = 1;

    if (filter?.customerId) {
      queryText += ` AND customer_id = $${idx++}`;
      params.push(filter.customerId);
    }
    if (filter?.driverId) {
      queryText += ` AND driver_id = $${idx++}`;
      params.push(filter.driverId);
    }
    if (filter?.status) {
      queryText += ` AND status = $${idx++}`;
      params.push(filter.status);
    }
    queryText += ' ORDER BY created_at DESC';

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
    extra?: { driverId?: string; cancellationReason?: string; cancelledBy?: 'customer' | 'driver'; fareFinal?: number; startedAt?: Date; completedAt?: Date }
  ): Promise<RideEntity | null> {
    await pool.query(
      `UPDATE rides SET status = $1, driver_id = COALESCE($2, driver_id), cancellation_reason = COALESCE($3, cancellation_reason), cancelled_by = COALESCE($4, cancelled_by), fare_final = COALESCE($5, fare_final), started_at = COALESCE($6, started_at), completed_at = COALESCE($7, completed_at), updated_at = NOW() WHERE id = $8`,
      [status, extra?.driverId || null, extra?.cancellationReason || null, extra?.cancelledBy || null, extra?.fareFinal || null, extra?.startedAt || null, extra?.completedAt || null, id]
    );

    return this.findById(id);
  }

  async saveRating(rideId: string, customerId: string, driverId: string, rating: number, comment?: string): Promise<void> {
    await pool.query(
      'INSERT INTO ride_ratings (id, ride_id, customer_id, driver_id, rating, comment) VALUES ($1, $2, $3, $4, $5, $6)',
      [uuidv4(), rideId, customerId, driverId, rating, comment || null]
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
      startedAt: row.started_at ? new Date(row.started_at) : null,
      completedAt: row.completed_at ? new Date(row.completed_at) : null,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}
