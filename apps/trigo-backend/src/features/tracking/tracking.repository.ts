import { pool } from '../../shared/database/connection';
import { ActiveDriverLocation, DriverLocationUpdate, RideTrackingPoint } from './tracking.types';
import { DriversRepository } from '../drivers/drivers.repository';
import { RIDE_STATUS } from '../../shared/constants/ride-status';
import { v4 as uuidv4 } from 'uuid';

/// Rides that mean the driver is occupied right now. Kept in step with the
/// rides service's own notion of an in-flight trip.
const ACTIVE_RIDE_STATUSES = [
  RIDE_STATUS.ACCEPTED,
  RIDE_STATUS.DRIVER_ARRIVING,
  RIDE_STATUS.IN_PROGRESS,
];

export class TrackingRepository {
  private driversRepository = new DriversRepository();

  async recordLocation(driverUserId: string, update: DriverLocationUpdate): Promise<void> {
    const driverProf = await this.driversRepository.findByUserId(driverUserId);
    const profileId = driverProf?.id || driverUserId;

    await this.driversRepository.updateLocation(profileId, update.lat, update.lng);

    await pool.query(
      'INSERT INTO ride_tracking (id, ride_id, driver_id, lat, lng, accuracy) VALUES ($1, $2, $3, $4, $5, $6)',
      [uuidv4(), update.rideId || null, driverUserId, update.lat, update.lng, update.accuracy || null]
    );
  }

  async getRideTrackingHistory(rideId: string): Promise<RideTrackingPoint[]> {
    const res = await pool.query(
      'SELECT lat, lng, accuracy, timestamp FROM ride_tracking WHERE ride_id = $1 ORDER BY timestamp ASC',
      [rideId]
    );
    return res.rows.map((row) => ({
      lat: parseFloat(row.lat),
      lng: parseFloat(row.lng),
      accuracy: row.accuracy ? parseFloat(row.accuracy) : null,
      timestamp: new Date(row.timestamp),
    }));
  }

  /**
   * Every online driver with a known position, plus the trip they are on.
   *
   * One query rather than findAll() + filtering in JS: the fleet map needs the
   * active ride, the municipality and a last-seen stamp, none of which the
   * generic driver select carries, and it avoids fetching each driver's
   * documents and payment methods just to drop them.
   */
  async getActiveDrivers(municipalityId?: string): Promise<ActiveDriverLocation[]> {
    const res = await pool.query(
      `SELECT dp.id            AS driver_id,
              dp.user_id       AS driver_user_id,
              CONCAT_WS(' ', u.first_name, u.last_name) AS driver_name,
              dp.tricycle_plate_number,
              dp.application_status,
              dp.current_lat,
              dp.current_lng,
              dp.updated_at    AS last_seen_at,
              m.id             AS municipality_id,
              m.name           AS municipality_name,
              ar.id            AS ride_id,
              ar.status        AS ride_status,
              ar.started_at,
              ar.pickup_lat, ar.pickup_lng, ar.pickup_address,
              ar.dropoff_lat, ar.dropoff_lng, ar.dropoff_address,
              CONCAT_WS(' ', cu.first_name, cu.last_name) AS customer_name
       FROM driver_profiles dp
       JOIN users u ON u.id = dp.user_id
       LEFT JOIN municipalities m ON m.id = dp.municipality_id
       LEFT JOIN LATERAL (
         SELECT r.*
         FROM rides r
         WHERE r.driver_id = dp.user_id
           AND r.status = ANY($2::text[])
         ORDER BY r.created_at DESC
         LIMIT 1
       ) ar ON true
       LEFT JOIN users cu ON cu.id = ar.customer_id
       WHERE dp.is_online = true
         AND dp.current_lat IS NOT NULL
         AND dp.current_lng IS NOT NULL
         AND ($1::uuid IS NULL OR dp.municipality_id = $1::uuid)
       ORDER BY (ar.id IS NOT NULL) DESC, dp.updated_at DESC`,
      [municipalityId ?? null, ACTIVE_RIDE_STATUSES]
    );

    return res.rows.map((row) => ({
      driverId: row.driver_id,
      driverUserId: row.driver_user_id,
      driverName: row.driver_name || undefined,
      tricyclePlateNumber: row.tricycle_plate_number || undefined,
      municipalityId: row.municipality_id ?? null,
      municipalityName: row.municipality_name ?? null,
      applicationStatus: row.application_status ?? undefined,
      lat: parseFloat(row.current_lat),
      lng: parseFloat(row.current_lng),
      isOnline: true,
      lastSeenAt: new Date(row.last_seen_at),
      activeRide: row.ride_id
        ? {
            rideId: row.ride_id,
            status: row.ride_status as RIDE_STATUS,
            customerName: row.customer_name || undefined,
            pickupAddress: row.pickup_address ?? null,
            dropoffAddress: row.dropoff_address ?? null,
            pickupLat: parseFloat(row.pickup_lat),
            pickupLng: parseFloat(row.pickup_lng),
            dropoffLat: parseFloat(row.dropoff_lat),
            dropoffLng: parseFloat(row.dropoff_lng),
            startedAt: row.started_at ? new Date(row.started_at) : null,
          }
        : null,
    }));
  }
}
