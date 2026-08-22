import { describe, it, expect, vi } from 'vitest';
import { MunicipalitiesService } from './municipalities.service';
import { MunicipalitiesRepository } from './municipalities.repository';

describe('MunicipalitiesService', () => {
  const service = new MunicipalitiesService();
  const mockMuni = {
    id: '11111111-1111-1111-1111-111111111111',
    name: 'Lapu-Lapu City',
    province: 'Cebu',
    centerLat: 10.3157,
    centerLng: 123.9575,
    radiusKm: 15.0,
    baseFare: 30.0,
    perKmRate: 10.0,
    exclusiveMultiplier: 1.5,
    minFare: 20,
    nightSurcharge: 0,
    maxPassengers: 4,
    isActive: true,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  it('fetches all municipalities', async () => {
    vi.spyOn(MunicipalitiesRepository.prototype, 'findAll').mockResolvedValue([mockMuni]);
    const list = await service.getAllMunicipalities();
    expect(list.length).toBeGreaterThan(0);
  });

  it('validates coordinate boundary correctly', async () => {
    vi.spyOn(MunicipalitiesRepository.prototype, 'findById').mockResolvedValue(mockMuni);
    const inside = await service.isWithinBoundary('11111111-1111-1111-1111-111111111111', 10.3157, 123.9575);
    expect(inside).toBe(true);

    const outside = await service.isWithinBoundary('11111111-1111-1111-1111-111111111111', 14.5995, 120.9842);
    expect(outside).toBe(false);
  });
});
