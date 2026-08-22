import { describe, it, expect, vi, beforeEach } from 'vitest';
import { RidesService } from './rides.service';
import { RidesRepository } from './rides.repository';
import { MunicipalitiesRepository } from '../municipalities/municipalities.repository';
import { DriversRepository } from '../drivers/drivers.repository';
import { PaymentsRepository } from '../payments/payments.repository';
import { AppError } from '../../shared/errors/app-error';
import { RIDE_STATUS } from '../../shared/constants/ride-status';
import { DRIVER_APPLICATION_STATUS, USER_ROLE } from '../../shared/constants/roles';

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
    exclusiveMultiplier: 1.5,
    minFare: 20,
    nightSurcharge: 0,
    maxPassengers: 4,
    isActive: true,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(() => {
    vi.restoreAllMocks();
  });

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

  it('rejects ride acceptance by users without an approved driver profile', async () => {
    vi.spyOn(DriversRepository.prototype, 'findByUserId').mockResolvedValue(null);

    await expect(service.acceptRide('44444444-4444-4444-4444-444444444444', 'customer-id'))
      .rejects.toMatchObject({ statusCode: 403 });
  });

  it('rejects ride acceptance by unapproved drivers', async () => {
    vi.spyOn(DriversRepository.prototype, 'findByUserId').mockResolvedValue({
      id: '33333333-3333-3333-3333-333333333333',
      userId: 'driver-user-id',
      municipalityId: mockMuni.id,
      licenseNumber: 'N01-1234567',
      tricyclePlateNumber: '123-ABC',
      tricycleModel: null,
      applicationStatus: DRIVER_APPLICATION_STATUS.PENDING,
      rejectionReason: null,
      isOnline: false,
      currentLat: null,
      currentLng: null,
      averageRating: 5,
      totalRides: 0,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    await expect(service.acceptRide('44444444-4444-4444-4444-444444444444', 'driver-user-id'))
      .rejects.toMatchObject({ statusCode: 403 });
  });

  it('prevents customers from cancelling rides they do not own', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue({
      id: '44444444-4444-4444-4444-444444444444',
      customerId: 'other-customer',
      driverId: null,
      municipalityId: mockMuni.id,
      pickupLat: 8.1575,
      pickupLng: 125.1278,
      pickupAddress: null,
      dropoffLat: 8.16,
      dropoffLng: 125.13,
      dropoffAddress: null,
      status: RIDE_STATUS.REQUESTED,
      fareEstimate: 50,
      fareFinal: null,
      distanceKm: 2,
      cancellationReason: null,
      cancelledBy: null,
      cancellationFee: 0,
      startedAt: null,
      completedAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    await expect(service.cancelRide('44444444-4444-4444-4444-444444444444', 'random-customer', USER_ROLE.CUSTOMER))
      .rejects.toMatchObject({ statusCode: 403 });
  });

  it('charges the base fare when a customer cancels after acceptance', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue({
      id: '44444444-4444-4444-4444-444444444444',
      customerId: 'owning-customer',
      driverId: 'assigned-driver',
      municipalityId: mockMuni.id,
      pickupLat: 8.1575,
      pickupLng: 125.1278,
      pickupAddress: null,
      dropoffLat: 8.16,
      dropoffLng: 125.13,
      dropoffAddress: null,
      status: RIDE_STATUS.ACCEPTED,
      fareEstimate: 50,
      fareFinal: null,
      distanceKm: 2,
      cancellationReason: null,
      cancelledBy: null,
      cancellationFee: 0,
      startedAt: null,
      completedAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    vi.spyOn(MunicipalitiesRepository.prototype, 'findById').mockResolvedValue(mockMuni);
    const updateSpy = vi.spyOn(RidesRepository.prototype, 'updateStatus').mockResolvedValue(null);

    await service.cancelRide('44444444-4444-4444-4444-444444444444', 'owning-customer', USER_ROLE.CUSTOMER);

    expect(updateSpy).toHaveBeenCalledWith(
      '44444444-4444-4444-4444-444444444444',
      RIDE_STATUS.CANCELLED,
      expect.objectContaining({ cancellationFee: mockMuni.baseFare })
    );
  });

  it('blocks ride completion when the ride is not in progress', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue({
      id: '44444444-4444-4444-4444-444444444444',
      customerId: 'owning-customer',
      driverId: 'assigned-driver',
      municipalityId: mockMuni.id,
      pickupLat: 8.1575,
      pickupLng: 125.1278,
      pickupAddress: null,
      dropoffLat: 8.16,
      dropoffLng: 125.13,
      dropoffAddress: null,
      status: RIDE_STATUS.COMPLETED,
      fareEstimate: 50,
      fareFinal: 50,
      distanceKm: 2,
      cancellationReason: null,
      cancelledBy: null,
      cancellationFee: 0,
      startedAt: null,
      completedAt: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    await expect(service.completeRide('44444444-4444-4444-4444-444444444444', 'assigned-driver'))
      .rejects.toBeInstanceOf(AppError);
  });
});

