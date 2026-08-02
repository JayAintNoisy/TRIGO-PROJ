import { pool } from '../../shared/database/connection';
import { DriverProfileEntity, DriverDocumentEntity, DriverApplicationInput } from './drivers.types';
import { DRIVER_APPLICATION_STATUS } from '../../shared/constants/roles';
import { v4 as uuidv4 } from 'uuid';

export class DriversRepository {
  async findByUserId(userId: string): Promise<DriverProfileEntity | null> {
    const res = await pool.query('SELECT * FROM driver_profiles WHERE user_id = $1', [userId]);
    if (res.rows.length === 0) return null;
    return this.mapRowToEntity(res.rows[0]);
  }

  async findById(id: string): Promise<DriverProfileEntity | null> {
    const res = await pool.query('SELECT * FROM driver_profiles WHERE id = $1', [id]);
    if (res.rows.length === 0) return null;
    return this.mapRowToEntity(res.rows[0]);
  }

  async findAll(): Promise<DriverProfileEntity[]> {
    const res = await pool.query('SELECT * FROM driver_profiles ORDER BY created_at DESC');
    return res.rows.map(this.mapRowToEntity);
  }

  async findApplications(status?: DRIVER_APPLICATION_STATUS): Promise<DriverProfileEntity[]> {
    if (status) {
      const res = await pool.query('SELECT * FROM driver_profiles WHERE application_status = $1 ORDER BY created_at DESC', [status]);
      return res.rows.map(this.mapRowToEntity);
    }
    return this.findAll();
  }

  async createApplication(userId: string, input: DriverApplicationInput): Promise<DriverProfileEntity> {
    const newId = uuidv4();
    const now = new Date();
    const docs: DriverDocumentEntity[] = input.documents.map((doc) => ({
      id: uuidv4(),
      driverProfileId: newId,
      documentType: doc.documentType,
      documentUrl: doc.documentUrl,
      createdAt: now,
    }));

    const entity: DriverProfileEntity = {
      id: newId,
      userId,
      municipalityId: input.municipalityId,
      licenseNumber: input.licenseNumber,
      tricyclePlateNumber: input.tricyclePlateNumber,
      tricycleModel: input.tricycleModel || null,
      applicationStatus: DRIVER_APPLICATION_STATUS.PENDING,
      isOnline: false,
      averageRating: 5.0,
      totalRides: 0,
      createdAt: now,
      updatedAt: now,
      documents: docs,
    };

    await pool.query(
      `INSERT INTO driver_profiles (id, user_id, municipality_id, license_number, tricycle_plate_number, tricycle_model, application_status, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [
        entity.id,
        entity.userId,
        entity.municipalityId,
        entity.licenseNumber,
        entity.tricyclePlateNumber,
        entity.tricycleModel,
        entity.applicationStatus,
        entity.createdAt,
        entity.updatedAt,
      ]
    );

    return entity;
  }

  async updateStatus(id: string, status: DRIVER_APPLICATION_STATUS, rejectionReason?: string): Promise<DriverProfileEntity | null> {
    await pool.query(
      'UPDATE driver_profiles SET application_status = $1, rejection_reason = $2, updated_at = NOW() WHERE id = $3',
      [status, rejectionReason || null, id]
    );
    return this.findById(id);
  }

  async setOnlineStatus(driverProfileId: string, isOnline: boolean): Promise<void> {
    await pool.query('UPDATE driver_profiles SET is_online = $1, updated_at = NOW() WHERE id = $2', [isOnline, driverProfileId]);
  }

  async updateLocation(driverProfileId: string, lat: number, lng: number): Promise<void> {
    await pool.query(
      'UPDATE driver_profiles SET current_lat = $1, current_lng = $2, updated_at = NOW() WHERE id = $3',
      [lat, lng, driverProfileId]
    );
  }

  private mapRowToEntity(row: any): DriverProfileEntity {
    return {
      id: row.id,
      userId: row.user_id,
      municipalityId: row.municipality_id,
      licenseNumber: row.license_number,
      tricyclePlateNumber: row.tricycle_plate_number,
      tricycleModel: row.tricycle_model,
      applicationStatus: row.application_status as DRIVER_APPLICATION_STATUS,
      rejectionReason: row.rejection_reason,
      isOnline: row.is_online,
      currentLat: row.current_lat ? parseFloat(row.current_lat) : null,
      currentLng: row.current_lng ? parseFloat(row.current_lng) : null,
      averageRating: parseFloat(row.average_rating || 5.0),
      totalRides: parseInt(row.total_rides || 0, 10),
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}
