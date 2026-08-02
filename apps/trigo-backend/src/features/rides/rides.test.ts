import { describe, it, expect, vi } from 'vitest';
import { RidesService } from './rides.service';
import { RidesRepository } from './rides.repository';
import { MunicipalitiesRepository } from '../municipalities/municipalities.repository';
import { RIDE_STATUS } from '../../shared/constants/ride-status';

describe('RidesService', () => {
  const service = new RidesService();
  const mockMuni = {
    id: '11111111-1111-1111-1111-111111111111',
    name: 'Malaybalay City',
    province: 'Bukidnon',
    centerLat: 8.1575,
    centerLng: 125.1278,
    radiusKm: 15.0,
    baseFare: 30.0,
    perKmRate: 10.0,
    isActive: true,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  it('creates ride request within valid municipality jurisdiction', async () => {
    vi.spyOn(MunicipalitiesRepository.prototype, 'findById').mockResolvedValue(mockMuni);
    vi.spyOn(RidesRepository.prototype, 'create').mockImplementation(async (data) => ({
      id: '44444444-4444-4444-4444-444444444444',
      ...data,
      createdAt: new Date(),
      updatedAt: new Date(),
    }));

    const ride = await service.requestRide('00000000-0000-0000-0000-000000000003', {
      municipalityId: '11111111-1111-1111-1111-111111111111',
      pickupLat: 8.1575,
      pickupLng: 125.1278,
      pickupAddress: 'City Hall',
      dropoffLat: 8.1600,
      dropoffLng: 125.1300,
      dropoffAddress: 'Public Market',
    });

    expect(ride.id).toBeDefined();
    expect(ride.status).toBe(RIDE_STATUS.REQUESTED);
    expect(ride.fareEstimate).toBeGreaterThan(25);
  });
});
