import { pool } from '../../shared/database/connection';
import { DriverProfileEntity, DriverDocumentEntity, DriverApplicationInput } from './drivers.types';
import { DRIVER_APPLICATION_STATUS } from '../../shared/constants/roles';
import { v4 as uuidv4 } from 'uuid';

const DRIVER_SELECT = `
  SELECT dp.*,
         u.name  AS user_name,
         u.phone AS user_phone,
         u.email AS user_email,
         m.name  AS municipality_name
  FROM driver_profiles dp
  LEFT JOIN users u ON u.id = dp.user_id
  LEFT JOIN municipalities m ON m.id = dp.municipality_id
`;

export class DriversRepository {
  async findByUserId(userId: string): Promise<DriverProfileEntity | null> {
    const res = await pool.query(`${DRIVER_SELECT} WHERE dp.user_id = $1`, [userId]);
    if (res.rows.length === 0) return null;
    return this.mapRowToEntity(res.rows[0]);
  }

  async findById(id: string): Promise<DriverProfileEntity | null> {
    const res = await pool.query(`${DRIVER_SELECT} WHERE dp.id = $1`, [id]);
    if (res.rows.length === 0) return null;
    return this.mapRowToEntity(res.rows[0]);
  }

  async findAll(): Promise<DriverProfileEntity[]> {
    const res = await pool.query(`${DRIVER_SELECT} ORDER BY dp.created_at DESC`);
    return res.rows.map(this.mapRowToEntity);
  }

  async findApplications(status?: DRIVER_APPLICATION_STATUS): Promise<DriverProfileEntity[]> {
    if (status) {
      const res = await pool.query(
        `${DRIVER_SELECT} WHERE dp.application_status = $1 ORDER BY dp.created_at DESC`,
        [status]
      );
      return res.rows.map(this.mapRowToEntity);
    }
    return this.findAll();
  }

  async findOnlineDrivers(): Promise<DriverProfileEntity[]> {
    const res = await pool.query(
      `${DRIVER_SELECT} WHERE dp.application_status = 'approved' AND dp.is_online = true ORDER BY dp.updated_at DESC`
    );
    return res.rows.map(this.mapRowToEntity);
  }

  async findDocumentsByProfileId(driverProfileId: string): Promise<DriverDocumentEntity[]> {
    const res = await pool.query(
      'SELECT * FROM driver_documents WHERE driver_profile_id = $1 ORDER BY created_at ASC',
      [driverProfileId]
    );
    return res.rows.map(this.mapDocumentRow);
  }

  async createApplication(userId: string, input: DriverApplicationInput): Promise<DriverProfileEntity> {
    const newId = uuidv4();
    const now = new Date();

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      await client.query(
        `INSERT INTO driver_profiles (id, user_id, municipality_id, license_number, tricycle_plate_number, tricycle_model, application_status, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [
          newId,
          userId,
          input.municipalityId,
          input.licenseNumber,
          input.tricyclePlateNumber,
          input.tricycleModel || null,
          DRIVER_APPLICATION_STATUS.PENDING,
          now,
          now,
        ]
      );

      // Persist uploaded documents so admin review has the actual evidence
      for (const doc of input.documents) {
        await client.query(
          'INSERT INTO driver_documents (id, driver_profile_id, document_type, document_url) VALUES ($1, $2, $3, $4)',
          [uuidv4(), newId, doc.documentType, doc.documentUrl]
        );
      }

      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

    const created = await this.findById(newId);
    return created!;
  }

  async replaceApplication(
    profileId: string,
    input: DriverApplicationInput
  ): Promise<DriverProfileEntity> {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      await client.query(
        `UPDATE driver_profiles
         SET municipality_id = $1, license_number = $2, tricycle_plate_number = $3,
             tricycle_model = $4, application_status = $5, rejection_reason = NULL,
             updated_at = NOW()
         WHERE id = $6`,
        [
          input.municipalityId,
          input.licenseNumber,
          input.tricyclePlateNumber,
          input.tricycleModel || null,
          DRIVER_APPLICATION_STATUS.PENDING,
          profileId,
        ]
      );

      // Swap in the freshly uploaded evidence wholesale
      await client.query('DELETE FROM driver_documents WHERE driver_profile_id = $1', [profileId]);
      for (const doc of input.documents) {
        await client.query(
          'INSERT INTO driver_documents (id, driver_profile_id, document_type, document_url) VALUES ($1, $2, $3, $4)',
          [uuidv4(), profileId, doc.documentType, doc.documentUrl]
        );
      }

      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

    const updated = await this.findById(profileId);
    return updated!;
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

  async incrementTotalRides(driverUserId: string): Promise<void> {
    await pool.query(
      'UPDATE driver_profiles SET total_rides = total_rides + 1, updated_at = NOW() WHERE user_id = $1',
      [driverUserId]
    );
  }

  async recalculateAverageRating(driverUserId: string): Promise<void> {
    await pool.query(
      `UPDATE driver_profiles
       SET average_rating = COALESCE((SELECT ROUND(AVG(rating)::numeric, 2) FROM ride_ratings WHERE driver_id = $1), average_rating),
           updated_at = NOW()
       WHERE user_id = $1`,
      [driverUserId]
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
      userName: row.user_name || undefined,
      userPhone: row.user_phone || undefined,
      userEmail: row.user_email || undefined,
      municipalityName: row.municipality_name || undefined,
    };
  }

  private mapDocumentRow(row: any): DriverDocumentEntity {
    return {
      id: row.id,
      driverProfileId: row.driver_profile_id,
      documentType: row.document_type,
      documentUrl: row.document_url,
      createdAt: new Date(row.created_at),
    };
  }
}
