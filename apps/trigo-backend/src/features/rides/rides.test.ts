import { describe, it, expect, vi, beforeEach } from 'vitest';
import { RidesService } from './rides.service';
import { RidesRepository } from './rides.repository';
import { MunicipalitiesRepository } from '../municipalities/municipalities.repository';
import { DriversRepository } from '../drivers/drivers.repository';
import { PaymentsRepository } from '../payments/payments.repository';
import { DriverPaymentMethodsRepository } from '../payments/driver-payment-methods.repository';
import { NotificationsService } from '../notifications/notifications.service';
import { AppError } from '../../shared/errors/app-error';
import { RIDE_STATUS } from '../../shared/constants/ride-status';
import { PAYMENT_METHOD, PAYMENT_STATUS } from '../../shared/constants/payment-status';
import { DRIVER_APPLICATION_STATUS, USER_ROLE } from '../../shared/constants/roles';

/**
 * Ride actions write notifications best-effort. Stub them so no test ever
 * reaches the database through the notification service.
 */
const stubNotifications = () => ({
  request: vi.spyOn(NotificationsService.prototype, 'notifyNewRideRequest').mockResolvedValue(0),
  started: vi.spyOn(NotificationsService.prototype, 'notifyRideStarted').mockResolvedValue(),
  completed: vi.spyOn(NotificationsService.prototype, 'notifyRideCompleted').mockResolvedValue(),
  cancelled: vi.spyOn(NotificationsService.prototype, 'notifyRideCancelled').mockResolvedValue(),
  paymentSent: vi.spyOn(NotificationsService.prototype, 'notifyPaymentSent').mockResolvedValue(),
  paymentReceived: vi.spyOn(NotificationsService.prototype, 'notifyPaymentReceived').mockResolvedValue(),
});

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
    const notifications = stubNotifications();

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
    // The request is offered to the drivers who could accept it.
    expect(notifications.request).toHaveBeenCalledWith(expect.objectContaining({ id: ride.id }));
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
    const notifications = stubNotifications();

    await service.cancelRide('44444444-4444-4444-4444-444444444444', 'owning-customer', USER_ROLE.CUSTOMER);

    expect(updateSpy).toHaveBeenCalledWith(
      '44444444-4444-4444-4444-444444444444',
      RIDE_STATUS.CANCELLED,
      expect.objectContaining({ cancellationFee: mockMuni.baseFare })
    );
    // The driver is told their ride fell through.
    expect(notifications.cancelled).toHaveBeenCalledWith(
      expect.objectContaining({ id: '44444444-4444-4444-4444-444444444444' }),
      'customer'
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

describe('RidesService payment method selection', () => {
  const service = new RidesService();
  const rideId = '44444444-4444-4444-4444-444444444444';
  const customerId = 'owning-customer';
  const driverId = 'assigned-driver';

  const mockRide = (overrides: Record<string, unknown> = {}) => ({
    id: rideId,
    customerId,
    driverId,
    municipalityId: '11111111-1111-1111-1111-111111111111',
    pickupLat: 8.1575,
    pickupLng: 125.1278,
    pickupAddress: null,
    dropoffLat: 8.16,
    dropoffLng: 125.13,
    dropoffAddress: null,
    status: RIDE_STATUS.IN_PROGRESS,
    fareEstimate: 50,
    fareFinal: null,
    distanceKm: 2,
    cancellationReason: null,
    cancelledBy: null,
    cancellationFee: 0,
    startedAt: null,
    completedAt: null,
    paymentMethod: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  });

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('stores a method the driver accepts', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide() as any);
    vi.spyOn(DriverPaymentMethodsRepository.prototype, 'findEnabledMethodsByDriverUserId')
      .mockResolvedValue([PAYMENT_METHOD.GCASH]);
    const updateSpy = vi.spyOn(RidesRepository.prototype, 'updatePaymentMethod').mockResolvedValue(null);

    await service.setRidePaymentMethod(rideId, customerId, PAYMENT_METHOD.GCASH);

    expect(updateSpy).toHaveBeenCalledWith(rideId, PAYMENT_METHOD.GCASH);
  });

  it('accepts cash without consulting the driver configuration', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide() as any);
    const driverMethodsSpy = vi.spyOn(
      DriverPaymentMethodsRepository.prototype,
      'findEnabledMethodsByDriverUserId'
    );
    const updateSpy = vi.spyOn(RidesRepository.prototype, 'updatePaymentMethod').mockResolvedValue(null);

    await service.setRidePaymentMethod(rideId, customerId, PAYMENT_METHOD.CASH);

    expect(updateSpy).toHaveBeenCalledWith(rideId, PAYMENT_METHOD.CASH);
    expect(driverMethodsSpy).not.toHaveBeenCalled();
  });

  it('rejects a method the driver has not enabled', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide() as any);
    vi.spyOn(DriverPaymentMethodsRepository.prototype, 'findEnabledMethodsByDriverUserId')
      .mockResolvedValue([PAYMENT_METHOD.GCASH]);
    const updateSpy = vi.spyOn(RidesRepository.prototype, 'updatePaymentMethod').mockResolvedValue(null);

    await expect(service.setRidePaymentMethod(rideId, customerId, PAYMENT_METHOD.MAYA))
      .rejects.toMatchObject({ statusCode: 400 });
    expect(updateSpy).not.toHaveBeenCalled();
  });

  it('requires an assigned driver', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide({ driverId: null }) as any);

    await expect(service.setRidePaymentMethod(rideId, customerId, PAYMENT_METHOD.CASH))
      .rejects.toThrow('Choose a driver before selecting a payment method');
  });

  it('only lets the passenger on the ride choose', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide() as any);

    await expect(service.setRidePaymentMethod(rideId, 'someone-else', PAYMENT_METHOD.CASH))
      .rejects.toMatchObject({ statusCode: 403 });
  });

  it('refuses to change the method once the ride is finished', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById')
      .mockResolvedValue(mockRide({ status: RIDE_STATUS.COMPLETED }) as any);

    await expect(service.setRidePaymentMethod(rideId, customerId, PAYMENT_METHOD.CASH))
      .rejects.toThrow('The payment method can only be chosen before the ride is completed');
  });

  it('records the chosen method when the ride completes', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById')
      .mockResolvedValue(mockRide({ paymentMethod: PAYMENT_METHOD.GCASH }) as any);
    vi.spyOn(RidesRepository.prototype, 'updateStatus').mockResolvedValue(null);
    vi.spyOn(DriverPaymentMethodsRepository.prototype, 'findEnabledMethodsByDriverUserId')
      .mockResolvedValue([PAYMENT_METHOD.GCASH]);
    vi.spyOn(DriversRepository.prototype, 'incrementTotalRides').mockResolvedValue();
    const paymentSpy = vi.spyOn(PaymentsRepository.prototype, 'create').mockResolvedValue({} as any);
    const notifications = stubNotifications();

    await service.completeRide(rideId, driverId);

    expect(paymentSpy).toHaveBeenCalledWith(
      rideId,
      50,
      PAYMENT_METHOD.GCASH,
      PAYMENT_STATUS.COMPLETED
    );
    // Both sides hear about the finish, and the settled method is labelled.
    expect(notifications.completed).toHaveBeenCalledTimes(2);
    expect(notifications.paymentSent).toHaveBeenCalledWith(expect.anything(), PAYMENT_METHOD.GCASH);
    expect(notifications.paymentReceived).toHaveBeenCalledWith(expect.anything(), PAYMENT_METHOD.GCASH);
  });

  it('falls back to cash when the chosen method is no longer accepted', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById')
      .mockResolvedValue(mockRide({ paymentMethod: PAYMENT_METHOD.MAYA }) as any);
    vi.spyOn(RidesRepository.prototype, 'updateStatus').mockResolvedValue(null);
    vi.spyOn(DriverPaymentMethodsRepository.prototype, 'findEnabledMethodsByDriverUserId')
      .mockResolvedValue([]);
    vi.spyOn(DriversRepository.prototype, 'incrementTotalRides').mockResolvedValue();
    const paymentSpy = vi.spyOn(PaymentsRepository.prototype, 'create').mockResolvedValue({} as any);
    stubNotifications();

    await service.completeRide(rideId, driverId);

    expect(paymentSpy).toHaveBeenCalledWith(
      rideId,
      50,
      PAYMENT_METHOD.CASH,
      PAYMENT_STATUS.COMPLETED
    );
  });

  it('records cash when the passenger never chose a method', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide() as any);
    vi.spyOn(RidesRepository.prototype, 'updateStatus').mockResolvedValue(null);
    vi.spyOn(DriversRepository.prototype, 'incrementTotalRides').mockResolvedValue();
    const paymentSpy = vi.spyOn(PaymentsRepository.prototype, 'create').mockResolvedValue({} as any);
    stubNotifications();

    await service.completeRide(rideId, driverId);

    expect(paymentSpy).toHaveBeenCalledWith(
      rideId,
      50,
      PAYMENT_METHOD.CASH,
      PAYMENT_STATUS.COMPLETED
    );
  });
});

describe('RidesService trip notifications', () => {
  const service = new RidesService();
  const rideId = '44444444-4444-4444-4444-444444444444';
  const driverId = 'assigned-driver';

  const mockRide = (overrides: Record<string, unknown> = {}) =>
    ({
      id: rideId,
      customerId: 'owning-customer',
      driverId,
      municipalityId: '11111111-1111-1111-1111-111111111111',
      pickupLat: 8.1575,
      pickupLng: 125.1278,
      pickupAddress: 'City Hall',
      dropoffLat: 8.16,
      dropoffLng: 125.13,
      dropoffAddress: 'Public Market',
      status: RIDE_STATUS.DRIVER_ARRIVING,
      fareEstimate: 50,
      fareFinal: null,
      distanceKm: 2,
      paymentMethod: null,
      startedAt: null,
      completedAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    }) as any;

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('tells both sides when the trip starts', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide());
    vi.spyOn(RidesRepository.prototype, 'updateStatus').mockResolvedValue(mockRide({ status: RIDE_STATUS.IN_PROGRESS }));
    const notifications = stubNotifications();

    await service.startRide(rideId, driverId);

    expect(notifications.started).toHaveBeenCalledTimes(1);
  });

  it('keeps the ride action working when the alert cannot be written', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide());
    const updated = mockRide({ status: RIDE_STATUS.IN_PROGRESS });
    vi.spyOn(RidesRepository.prototype, 'updateStatus').mockResolvedValue(updated);
    vi.spyOn(NotificationsService.prototype, 'notifyRideStarted').mockRejectedValue(
      new Error('notification store down')
    );

    await expect(service.startRide(rideId, driverId)).resolves.toBe(updated);
  });
});

describe('RidesService ratings', () => {
  const service = new RidesService();
  const rideId = '44444444-4444-4444-4444-444444444444';
  const customerId = 'owning-customer';
  const driverId = 'assigned-driver';

  const completedRide = (overrides: Record<string, unknown> = {}) =>
    ({
      id: rideId,
      customerId,
      driverId,
      municipalityId: '11111111-1111-1111-1111-111111111111',
      pickupLat: 8.1575,
      pickupLng: 125.1278,
      dropoffLat: 8.16,
      dropoffLng: 125.13,
      status: RIDE_STATUS.COMPLETED,
      fareEstimate: 50,
      fareFinal: 55,
      distanceKm: 2,
      startedAt: new Date('2026-01-01T09:00:00Z'),
      completedAt: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    }) as any;

  const hoursAgo = (hours: number) => new Date(Date.now() - hours * 60 * 60 * 1000);

  beforeEach(() => {
    vi.restoreAllMocks();
    vi.spyOn(DriversRepository.prototype, 'recalculateAverageRating').mockResolvedValue();
  });

  it('records a first rating and refreshes the driver average', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(completedRide());
    vi.spyOn(RidesRepository.prototype, 'findRatingByRideId').mockResolvedValue(null);
    const save = vi.spyOn(RidesRepository.prototype, 'saveRating').mockResolvedValue();
    const average = vi.spyOn(DriversRepository.prototype, 'recalculateAverageRating').mockResolvedValue();

    await service.rateRide(rideId, customerId, { rating: 5, comment: 'Great' });

    expect(save).toHaveBeenCalledWith(rideId, customerId, driverId, 5, 'Great');
    expect(average).toHaveBeenCalledWith(driverId);
  });

  it('refuses a second rating so the app never re-prompts silently', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(completedRide());
    vi.spyOn(RidesRepository.prototype, 'findRatingByRideId').mockResolvedValue({
      id: 'rating-1',
      rating: 4,
      comment: 'Good',
      createdAt: new Date(),
    });
    const save = vi.spyOn(RidesRepository.prototype, 'saveRating').mockResolvedValue();

    await expect(service.rateRide(rideId, customerId, { rating: 1 })).rejects.toMatchObject({
      statusCode: 400,
    });
    expect(save).not.toHaveBeenCalled();
  });

  it('lets the passenger change their rating inside the window', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(
      completedRide({ completedAt: hoursAgo(2) })
    );
    vi.spyOn(RidesRepository.prototype, 'findRatingByRideId').mockResolvedValue({
      id: 'rating-1',
      rating: 3,
      comment: 'Okay',
      createdAt: hoursAgo(2),
    });
    const update = vi.spyOn(RidesRepository.prototype, 'updateRating').mockResolvedValue();
    const average = vi.spyOn(DriversRepository.prototype, 'recalculateAverageRating').mockResolvedValue();

    await service.updateRideRating(rideId, customerId, { rating: 5, comment: 'Changed my mind' });

    expect(update).toHaveBeenCalledWith(rideId, 5, 'Changed my mind');
    expect(average).toHaveBeenCalledWith(driverId);
  });

  it('locks the rating once the edit window has closed', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(
      completedRide({ completedAt: hoursAgo(25) })
    );
    vi.spyOn(RidesRepository.prototype, 'findRatingByRideId').mockResolvedValue({
      id: 'rating-1',
      rating: 3,
      comment: 'Okay',
      createdAt: hoursAgo(25),
    });
    const update = vi.spyOn(RidesRepository.prototype, 'updateRating').mockResolvedValue();

    await expect(
      service.updateRideRating(rideId, customerId, { rating: 5 })
    ).rejects.toThrow(/24 hours/);
    expect(update).not.toHaveBeenCalled();
  });

  it('has nothing to edit before a rating exists', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(completedRide());
    vi.spyOn(RidesRepository.prototype, 'findRatingByRideId').mockResolvedValue(null);

    await expect(
      service.updateRideRating(rideId, customerId, { rating: 5 })
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it('refuses edits from anyone but the passenger who booked', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(completedRide());
    const update = vi.spyOn(RidesRepository.prototype, 'updateRating').mockResolvedValue();

    await expect(
      service.updateRideRating(rideId, 'someone-else', { rating: 1 })
    ).rejects.toMatchObject({ statusCode: 403 });
    await expect(
      service.updateRideRating(rideId, driverId, { rating: 1 })
    ).rejects.toMatchObject({ statusCode: 403 });
    expect(update).not.toHaveBeenCalled();
  });

  it('refuses to rate a trip that is not finished', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(
      completedRide({ status: RIDE_STATUS.IN_PROGRESS })
    );

    await expect(
      service.updateRideRating(rideId, customerId, { rating: 5 })
    ).rejects.toMatchObject({ statusCode: 400 });
  });
});

