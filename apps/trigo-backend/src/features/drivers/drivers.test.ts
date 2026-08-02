import { describe, it, expect, vi } from 'vitest';
import { DriversService } from './drivers.service';
import { DriversRepository } from './drivers.repository';
import { DRIVER_APPLICATION_STATUS } from '../../shared/constants/roles';

describe('DriversService', () => {
  const service = new DriversService();
  const mockDriver = {
    id: '33333333-3333-3333-3333-333333333333',
    userId: '00000000-0000-0000-0000-000000000002',
    municipalityId: '11111111-1111-1111-1111-111111111111',
    licenseNumber: 'N01-12-345678',
    tricyclePlateNumber: '123-ABC',
    tricycleModel: 'Kawasaki Barako 175',
    applicationStatus: DRIVER_APPLICATION_STATUS.APPROVED,
    isOnline: true,
    currentLat: 8.158,
    currentLng: 125.129,
    averageRating: 4.8,
    totalRides: 42,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  it('fetches existing driver profile by user ID', async () => {
    vi.spyOn(DriversRepository.prototype, 'findByUserId').mockResolvedValue(mockDriver);
    const profile = await service.getOwnProfile('00000000-0000-0000-0000-000000000002');
    expect(profile.licenseNumber).toBe('N01-12-345678');
  });

  it('toggles online status', async () => {
    vi.spyOn(DriversRepository.prototype, 'findByUserId').mockResolvedValue(mockDriver);
    vi.spyOn(DriversRepository.prototype, 'setOnlineStatus').mockResolvedValue();
    vi.spyOn(DriversRepository.prototype, 'findById').mockResolvedValue({ ...mockDriver, isOnline: false });

    const updated = await service.toggleOnlineStatus('00000000-0000-0000-0000-000000000002', false);
    expect(updated.isOnline).toBe(false);
  });
});
