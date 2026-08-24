import { MunicipalitiesRepository } from './municipalities.repository';
import { CreateMunicipalityInput, UpdateFareConfigInput, UpdateMunicipalityInput } from './municipalities.types';
import { calculateDistanceKm } from '../../shared/utils/calculate-distance';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';

/**
 * Standard Ray-casting algorithm to test if a point (lat, lng) lies within a closed polygon ring.
 * Ring vertices are in [lng, lat] order as per GeoJSON specification.
 */
export function isPointInPolygonRing(lat: number, lng: number, ring: [number, number][]): boolean {
  let inside = false;
  if (!ring || ring.length < 3) return false;

  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const xi = ring[i][0], yi = ring[i][1];
    const xj = ring[j][0], yj = ring[j][1];

    const intersect = ((yi > lat) !== (yj > lat))
        && (lng < (xj - xi) * (lat - yi) / (yj - yi + 0.000000000001) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

export class MunicipalitiesService {
  private repository = new MunicipalitiesRepository();

  async getAllMunicipalities() {
    return this.repository.findAll();
  }

  async getMunicipalityById(id: string) {
    const municipality = await this.repository.findById(id);
    if (!municipality) {
      throw new AppError('Municipality not found', 404, ERROR_CODES.NOT_FOUND);
    }
    return municipality;
  }

  async createMunicipality(input: CreateMunicipalityInput) {
    return this.repository.create(input);
  }

  async updateFareConfig(id: string, input: UpdateFareConfigInput) {
    const updated = await this.repository.updateFareConfig(id, input);
    if (!updated) {
      throw new AppError('Municipality not found', 404, ERROR_CODES.NOT_FOUND);
    }
    return updated;
  }

  async updateMunicipality(id: string, input: UpdateMunicipalityInput) {
    const updated = await this.repository.update(id, input);
    if (!updated) {
      throw new AppError('Municipality not found', 404, ERROR_CODES.NOT_FOUND);
    }
    return updated;
  }

  // Deactivates the municipality (soft delete) since rides reference it
  async deleteMunicipality(id: string) {
    const deleted = await this.repository.softDelete(id);
    if (!deleted) {
      throw new AppError('Municipality not found', 404, ERROR_CODES.NOT_FOUND);
    }
    return deleted;
  }

  /**
   * Verifies if a GPS coordinate is within the municipality's custom geometry boundary
   * or falls back to radius containment.
   */
  async isWithinBoundary(municipalityId: string, lat: number, lng: number): Promise<boolean> {
    const muni = await this.getMunicipalityById(municipalityId);

    // If custom polygon geometry exists, check point-in-polygon
    if (muni.boundaryGeojson) {
      try {
        const geom = muni.boundaryGeojson;
        if (geom.type === 'Polygon' && Array.isArray(geom.coordinates) && geom.coordinates.length > 0) {
          const outerRing = geom.coordinates[0] as [number, number][];
          return isPointInPolygonRing(lat, lng, outerRing);
        } else if (geom.type === 'MultiPolygon' && Array.isArray(geom.coordinates)) {
          for (const poly of geom.coordinates) {
            if (Array.isArray(poly) && poly.length > 0) {
              if (isPointInPolygonRing(lat, lng, poly[0] as [number, number][])) {
                return true;
              }
            }
          }
          return false;
        } else if (Array.isArray(geom) && geom.length >= 3) {
          // Direct coordinate list [[lng, lat], ...]
          return isPointInPolygonRing(lat, lng, geom as [number, number][]);
        }
      } catch (_) {
        // Fallback to circular radius if GeoJSON parsing fails
      }
    }

    // Default circular radius containment
    const distanceFromCenter = calculateDistanceKm(muni.centerLat, muni.centerLng, lat, lng);
    return distanceFromCenter <= muni.radiusKm;
  }
}
