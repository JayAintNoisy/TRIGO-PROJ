import { pool } from '../../shared/database/connection';
import { MunicipalityEntity, CreateMunicipalityInput, UpdateFareConfigInput } from './municipalities.types';
import { v4 as uuidv4 } from 'uuid';

export class MunicipalitiesRepository {
  async findAll(): Promise<MunicipalityEntity[]> {
    const res = await pool.query('SELECT * FROM municipalities WHERE is_active = true ORDER BY name ASC');
    return res.rows.map(this.mapRowToEntity);
  }

  async findById(id: string): Promise<MunicipalityEntity | null> {
    const res = await pool.query('SELECT * FROM municipalities WHERE id = $1', [id]);
    if (res.rows.length === 0) return null;
    return this.mapRowToEntity(res.rows[0]);
  }

  async create(input: CreateMunicipalityInput): Promise<MunicipalityEntity> {
    const newId = uuidv4();
    const now = new Date();
    const entity: MunicipalityEntity = {
      id: newId,
      name: input.name,
      province: input.province || null,
      centerLat: input.centerLat,
      centerLng: input.centerLng,
      radiusKm: input.radiusKm,
      baseFare: input.baseFare ?? 30.0,
      perKmRate: input.perKmRate ?? 10.0,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    };

    await pool.query(
      `INSERT INTO municipalities (id, name, province, center_lat, center_lng, radius_km, base_fare, per_km_rate, is_active, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
      [
        entity.id,
        entity.name,
        entity.province,
        entity.centerLat,
        entity.centerLng,
        entity.radiusKm,
        entity.baseFare,
        entity.perKmRate,
        entity.isActive,
        entity.createdAt,
        entity.updatedAt,
      ]
    );

    return entity;
  }

  async updateFareConfig(id: string, input: UpdateFareConfigInput): Promise<MunicipalityEntity | null> {
    await pool.query(
      'UPDATE municipalities SET base_fare = $1, per_km_rate = $2, updated_at = NOW() WHERE id = $3',
      [input.baseFare, input.perKmRate, id]
    );

    return this.findById(id);
  }

  private mapRowToEntity(row: any): MunicipalityEntity {
    return {
      id: row.id,
      name: row.name,
      province: row.province,
      centerLat: parseFloat(row.center_lat),
      centerLng: parseFloat(row.center_lng),
      radiusKm: parseFloat(row.radius_km),
      baseFare: parseFloat(row.base_fare),
      perKmRate: parseFloat(row.per_km_rate),
      isActive: row.is_active,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}
