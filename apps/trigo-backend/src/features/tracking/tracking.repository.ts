import { pool } from '../../shared/database/connection';
import { ActiveDriverLocation, DriverLocationUpdate, RideTrackingPoint } from './tracking.types';
import { DriversRepository } from '../drivers/drivers.repository';
import { v4 as uuidv4 } from 'uuid';

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

  async getActiveDrivers(): Promise<ActiveDriverLocation[]> {
    const drivers = await this.driversRepository.findAll();
    return drivers
      .filter((d) => d.isOnline && d.currentLat && d.currentLng)
      .map((d) => ({
        driverId: d.id,
        driverName: d.userName || 'Juan Dela Cruz',
        tricyclePlateNumber: d.tricyclePlateNumber,
        lat: d.currentLat!,
        lng: d.currentLng!,
        isOnline: d.isOnline,
        updatedAt: d.updatedAt,
      }));
  }
}
