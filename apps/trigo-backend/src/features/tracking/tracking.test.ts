import { describe, it, expect, vi, beforeEach } from 'vitest';
import { TrackingService } from './tracking.service';
import { TrackingRepository } from './tracking.repository';
import { ActiveDriverLocation } from './tracking.types';
import { RIDE_STATUS } from '../../shared/constants/ride-status';
import { DRIVER_APPLICATION_STATUS } from '../../shared/constants/roles';

const MUNICIPALITY_ID = '11111111-1111-1111-1111-111111111111';

const activeDriver = (overrides: Partial<ActiveDriverLocation> = {}): ActiveDriverLocation => ({
  driverId: '33333333-3333-3333-3333-333333333333',
  driverUserId: '00000000-0000-0000-0000-000000000002',
  driverName: 'Juan Dela Cruz',
  tricyclePlateNumber: '123-ABC',
  municipalityId: MUNICIPALITY_ID,
  municipalityName: 'Malaybalay City',
  applicationStatus: DRIVER_APPLICATION_STATUS.APPROVED,
  lat: 8.158,
  lng: 125.129,
  isOnline: true,
  lastSeenAt: new Date(),
  activeRide: null,
  ...overrides,
});

describe('TrackingService', () => {
  const service = new TrackingService();

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('records location update for driver', async () => {
    vi.spyOn(TrackingRepository.prototype, 'recordLocation').mockResolvedValue();
    const res = await service.recordLocation('00000000-0000-0000-0000-000000000002', {
      lat: 8.158,
      lng: 125.129,
      accuracy: 5,
    });
    expect(res.success).toBe(true);
  });

  it('returns the live fleet with each driver position', async () => {
    const drivers = [activeDriver()];
    vi.spyOn(TrackingRepository.prototype, 'getActiveDrivers').mockResolvedValue(drivers);

    await expect(service.getActiveDrivers()).resolves.toBe(drivers);
  });

  it('reports the trip a driver is on, so the fleet map can tell busy from idle', async () => {
    const onTrip = activeDriver({
      activeRide: {
        rideId: '44444444-4444-4444-4444-444444444444',
        status: RIDE_STATUS.IN_PROGRESS,
        customerName: 'Maria Clara',
        pickupAddress: 'City Hall',
        dropoffAddress: 'Public Market',
        pickupLat: 8.1575,
        pickupLng: 125.1278,
        dropoffLat: 8.16,
        dropoffLng: 125.13,
        startedAt: new Date(),
      },
    });
    vi.spyOn(TrackingRepository.prototype, 'getActiveDrivers').mockResolvedValue([onTrip]);

    const [driver] = await service.getActiveDrivers();

    expect(driver.activeRide?.rideId).toBe('44444444-4444-4444-4444-444444444444');
    expect(driver.activeRide?.status).toBe(RIDE_STATUS.IN_PROGRESS);
    expect(driver.activeRide?.customerName).toBe('Maria Clara');
  });

  it('passes a municipality filter through to the query', async () => {
    const spy = vi
      .spyOn(TrackingRepository.prototype, 'getActiveDrivers')
      .mockResolvedValue([]);

    await service.getActiveDrivers(MUNICIPALITY_ID);
    expect(spy).toHaveBeenCalledWith(MUNICIPALITY_ID);

    await service.getActiveDrivers();
    expect(spy).toHaveBeenLastCalledWith(undefined);
  });

  it('is empty when nobody is online', async () => {
    vi.spyOn(TrackingRepository.prototype, 'getActiveDrivers').mockResolvedValue([]);

    await expect(service.getActiveDrivers()).resolves.toEqual([]);
  });
});
