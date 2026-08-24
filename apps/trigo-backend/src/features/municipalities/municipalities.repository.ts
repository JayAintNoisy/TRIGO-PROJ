import { pool } from '../../shared/database/connection';
import { MunicipalityEntity, CreateMunicipalityInput, UpdateFareConfigInput, UpdateMunicipalityInput } from './municipalities.types';
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
      exclusiveMultiplier: 1.5,
      minFare: 20,
      nightSurcharge: 0,
      maxPassengers: 4,
      boundaryGeojson: input.boundaryGeojson || null,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    };

    await pool.query(
      `INSERT INTO municipalities (id, name, province, center_lat, center_lng, radius_km, base_fare, per_km_rate, boundary_geojson, is_active, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
      [
        entity.id,
        entity.name,
        entity.province,
        entity.centerLat,
        entity.centerLng,
        entity.radiusKm,
        entity.baseFare,
        entity.perKmRate,
        entity.boundaryGeojson ? JSON.stringify(entity.boundaryGeojson) : null,
        entity.isActive,
        entity.createdAt,
        entity.updatedAt,
      ]
    );

    return entity;
  }

  async updateFareConfig(id: string, input: UpdateFareConfigInput): Promise<MunicipalityEntity | null> {
    const fieldMap: Record<string, string> = {
      baseFare: 'base_fare',
      perKmRate: 'per_km_rate',
      exclusiveMultiplier: 'exclusive_multiplier',
      minFare: 'min_fare',
      nightSurcharge: 'night_surcharge',
      maxPassengers: 'max_passengers',
    };

    const updates: string[] = [];
    const params: any[] = [];
    let idx = 1;

    for (const [key, column] of Object.entries(fieldMap)) {
      if (input[key as keyof UpdateFareConfigInput] !== undefined) {
        updates.push(`${column} = $${idx++}`);
        params.push(input[key as keyof UpdateFareConfigInput]);
      }
    }
    if (updates.length === 0) return this.findById(id);

    updates.push('updated_at = NOW()');
    await pool.query(`UPDATE municipalities SET ${updates.join(', ')} WHERE id = $${idx}`, [...params, id]);

    return this.findById(id);
  }

  async update(id: string, input: UpdateMunicipalityInput): Promise<MunicipalityEntity | null> {
    const updates: string[] = [];
    const params: any[] = [];
    let idx = 1;

    const fieldMap: Record<string, string> = {
      name: 'name',
      province: 'province',
      centerLat: 'center_lat',
      centerLng: 'center_lng',
      radiusKm: 'radius_km',
      baseFare: 'base_fare',
      perKmRate: 'per_km_rate',
      boundaryGeojson: 'boundary_geojson',
      isActive: 'is_active',
    };

    for (const [key, column] of Object.entries(fieldMap)) {
      if (input[key as keyof UpdateMunicipalityInput] !== undefined) {
        updates.push(`${column} = $${idx++}`);
        const val = input[key as keyof UpdateMunicipalityInput];
        if (key === 'boundaryGeojson' && val !== null && val !== undefined) {
          params.push(typeof val === 'string' ? val : JSON.stringify(val));
        } else {
          params.push(val);
        }
      }
    }

    if (updates.length === 0) return this.findById(id);

    updates.push(`updated_at = NOW()`);
    await pool.query(`UPDATE municipalities SET ${updates.join(', ')} WHERE id = $${idx}`, [...params, id]);

    return this.findById(id);
  }

  // Soft delete — rides and driver profiles reference municipalities, so the row
  // is deactivated instead of removed
  async softDelete(id: string): Promise<MunicipalityEntity | null> {
    await pool.query('UPDATE municipalities SET is_active = false, updated_at = NOW() WHERE id = $1', [id]);
    return this.findById(id);
  }

  private mapRowToEntity(row: any): MunicipalityEntity {
    let boundaryGeojson: any = null;
    if (row.boundary_geojson) {
      if (typeof row.boundary_geojson === 'string') {
        try {
          boundaryGeojson = JSON.parse(row.boundary_geojson);
        } catch (_) {
          boundaryGeojson = row.boundary_geojson;
        }
      } else {
        boundaryGeojson = row.boundary_geojson;
      }
    }

    return {
      id: row.id,
      name: row.name,
      province: row.province,
      centerLat: parseFloat(row.center_lat),
      centerLng: parseFloat(row.center_lng),
      radiusKm: parseFloat(row.radius_km),
      baseFare: parseFloat(row.base_fare),
      perKmRate: parseFloat(row.per_km_rate),
      exclusiveMultiplier: row.exclusive_multiplier !== null && row.exclusive_multiplier !== undefined ? parseFloat(row.exclusive_multiplier) : 1.5,
      minFare: row.min_fare !== null && row.min_fare !== undefined ? parseFloat(row.min_fare) : 20,
      nightSurcharge: row.night_surcharge !== null && row.night_surcharge !== undefined ? parseFloat(row.night_surcharge) : 0,
      maxPassengers: row.max_passengers ? parseInt(row.max_passengers, 10) : 4,
      boundaryGeojson,
      isActive: row.is_active,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}
