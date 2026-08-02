import { MunicipalitiesRepository } from './municipalities.repository';
import { CreateMunicipalityInput, UpdateFareConfigInput } from './municipalities.types';
import { calculateDistanceKm } from '../../shared/utils/calculate-distance';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';

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

  /**
   * Verifies if a GPS coordinate is within the municipality's radius boundary.
   */
  async isWithinBoundary(municipalityId: string, lat: number, lng: number): Promise<boolean> {
    const muni = await this.getMunicipalityById(municipalityId);
    const distanceFromCenter = calculateDistanceKm(muni.centerLat, muni.centerLng, lat, lng);
    return distanceFromCenter <= muni.radiusKm;
  }
}
