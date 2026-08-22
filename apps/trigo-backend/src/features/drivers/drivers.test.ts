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

  it('moves a pending application into review', async () => {
    const pending = { ...mockDriver, applicationStatus: DRIVER_APPLICATION_STATUS.PENDING };
    vi.spyOn(DriversRepository.prototype, 'findById').mockResolvedValue(pending);
    vi.spyOn(DriversRepository.prototype, 'updateStatus').mockResolvedValue({
      ...pending,
      applicationStatus: DRIVER_APPLICATION_STATUS.REVIEWING,
    });

    const reviewing = await service.startReview(pending.id);
    expect(reviewing!.applicationStatus).toBe(DRIVER_APPLICATION_STATUS.REVIEWING);
  });

  it('refuses to review an application that is not pending', async () => {
    const approved = { ...mockDriver, applicationStatus: DRIVER_APPLICATION_STATUS.APPROVED };
    vi.spyOn(DriversRepository.prototype, 'findById').mockResolvedValue(approved);

    await expect(service.startReview(approved.id)).rejects.toThrow(
      'Only pending applications can move to review',
    );
  });

  it('resubmits a rejected application instead of creating a duplicate', async () => {
    const rejected = { ...mockDriver, applicationStatus: DRIVER_APPLICATION_STATUS.REJECTED };
    const input = {
      municipalityId: '11111111-1111-1111-1111-111111111111',
      licenseNumber: 'N01-99-999999',
      tricyclePlateNumber: '999-ZZZ',
      documents: [{ documentType: 'license_photo', documentUrl: '/uploads/driver-documents/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.png' }],
    };
    vi.spyOn(DriversRepository.prototype, 'findByUserId').mockResolvedValue(rejected);
    const replaceSpy = vi
      .spyOn(DriversRepository.prototype, 'replaceApplication')
      .mockResolvedValue({ ...rejected, applicationStatus: DRIVER_APPLICATION_STATUS.PENDING });

    await service.apply(rejected.userId, input);
    expect(replaceSpy).toHaveBeenCalledWith(rejected.id, input);
  });

  it('blocks resubmission while an application is under review', async () => {
    const reviewing = { ...mockDriver, applicationStatus: DRIVER_APPLICATION_STATUS.REVIEWING };
    vi.spyOn(DriversRepository.prototype, 'findByUserId').mockResolvedValue(reviewing);

    await expect(service.apply(reviewing.userId, {} as any)).rejects.toThrow(
      'Your application is currently being reviewed',
    );
  });
});
