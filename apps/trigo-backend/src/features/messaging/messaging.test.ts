import { describe, it, expect, vi, beforeEach } from 'vitest';
import { MessagingService, CHAT_WRITABLE_AFTER_COMPLETION_HOURS } from './messaging.service';
import { MessagingRepository } from './messaging.repository';
import { RidesRepository } from '../rides/rides.repository';
import { NotificationsService } from '../notifications/notifications.service';
import { RIDE_STATUS } from '../../shared/constants/ride-status';
import { AppError } from '../../shared/errors/app-error';

const RIDE_ID = 'ride-uuid-001';
const CUSTOMER_ID = 'customer-uuid-001';
const DRIVER_ID = 'driver-uuid-001';

const mockRide = (overrides: Record<string, unknown> = {}) =>
  ({
    id: RIDE_ID,
    customerId: CUSTOMER_ID,
    driverId: DRIVER_ID,
    municipalityId: 'muni-uuid-001',
    pickupLat: 8.1575,
    pickupLng: 125.1278,
    pickupAddress: 'City Hall',
    dropoffLat: 8.16,
    dropoffLng: 125.13,
    dropoffAddress: 'Public Market',
    status: RIDE_STATUS.IN_PROGRESS,
    fareEstimate: 85,
    fareFinal: null,
    distanceKm: 2,
    customerName: 'Maria Clara',
    driverName: 'Juan Dela Cruz',
    completedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  }) as any;

const mockMessage = (overrides: Record<string, unknown> = {}) => ({
  id: 'msg-1',
  rideId: RIDE_ID,
  senderId: CUSTOMER_ID,
  body: 'I am at the gate',
  readAt: null,
  createdAt: new Date(),
  ...overrides,
});

describe('MessagingService', () => {
  const service = new MessagingService();

  beforeEach(() => {
    vi.restoreAllMocks();
    vi.spyOn(NotificationsService.prototype, 'notifyNewMessage').mockResolvedValue();
  });

  it('returns the thread to either participant', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide());
    const listSpy = vi
      .spyOn(MessagingRepository.prototype, 'findByRideId')
      .mockResolvedValue([mockMessage()] as any);

    await expect(service.listMessages(RIDE_ID, CUSTOMER_ID)).resolves.toHaveLength(1);
    await expect(service.listMessages(RIDE_ID, DRIVER_ID)).resolves.toHaveLength(1);
    expect(listSpy).toHaveBeenCalledTimes(2);
  });

  it('rejects an unknown ride', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(null);

    await expect(service.listMessages(RIDE_ID, CUSTOMER_ID)).rejects.toMatchObject({ statusCode: 404 });
  });

  it('rejects anyone who is not on the ride', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide());
    const createSpy = vi.spyOn(MessagingRepository.prototype, 'create').mockResolvedValue(mockMessage() as any);

    await expect(service.sendMessage(RIDE_ID, 'stranger', 'hello')).rejects.toMatchObject({
      statusCode: 403,
    });
    expect(createSpy).not.toHaveBeenCalled();
  });

  it('stores a trimmed message and alerts the other party once', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide());
    const createSpy = vi
      .spyOn(MessagingRepository.prototype, 'create')
      .mockResolvedValue(mockMessage({ body: 'On my way' }) as any);
    const notifySpy = vi.spyOn(NotificationsService.prototype, 'notifyNewMessage').mockResolvedValue();

    await service.sendMessage(RIDE_ID, CUSTOMER_ID, '  On my way  ');

    expect(createSpy).toHaveBeenCalledWith(RIDE_ID, CUSTOMER_ID, 'On my way');
    expect(notifySpy).toHaveBeenCalledTimes(1);
    expect(notifySpy).toHaveBeenCalledWith(expect.objectContaining({ id: RIDE_ID }), 'passenger', 'On my way');
  });

  it('rejects an empty message body', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide());

    await expect(service.sendMessage(RIDE_ID, CUSTOMER_ID, '   ')).rejects.toBeInstanceOf(AppError);
  });

  it('blocks messaging before a driver accepts', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById')
      .mockResolvedValue(mockRide({ driverId: null, status: RIDE_STATUS.REQUESTED }));

    await expect(service.sendMessage(RIDE_ID, CUSTOMER_ID, 'hello')).rejects.toThrow(
      'You can only message once a driver has accepted this ride'
    );
  });

  it('blocks messaging on a cancelled ride', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById')
      .mockResolvedValue(mockRide({ status: RIDE_STATUS.CANCELLED }));

    await expect(service.sendMessage(RIDE_ID, DRIVER_ID, 'hello')).rejects.toThrow('This ride was cancelled');
  });

  it('keeps a finished thread open for a while, then closes it', async () => {
    const recent = new Date();
    recent.setHours(recent.getHours() - (CHAT_WRITABLE_AFTER_COMPLETION_HOURS - 1));
    vi.spyOn(RidesRepository.prototype, 'findById')
      .mockResolvedValue(mockRide({ status: RIDE_STATUS.COMPLETED, completedAt: recent }));
    const createSpy = vi.spyOn(MessagingRepository.prototype, 'create').mockResolvedValue(mockMessage() as any);

    await service.sendMessage(RIDE_ID, CUSTOMER_ID, 'I left my bag');
    expect(createSpy).toHaveBeenCalledTimes(1);

    const old = new Date();
    old.setHours(old.getHours() - (CHAT_WRITABLE_AFTER_COMPLETION_HOURS + 1));
    vi.spyOn(RidesRepository.prototype, 'findById')
      .mockResolvedValue(mockRide({ status: RIDE_STATUS.COMPLETED, completedAt: old }));

    await expect(service.sendMessage(RIDE_ID, CUSTOMER_ID, 'still there?')).rejects.toThrow(
      'This ride has ended'
    );
  });

  it('marks only the messages the reader received', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide());
    const readSpy = vi
      .spyOn(MessagingRepository.prototype, 'markThreadRead')
      .mockResolvedValue(2);

    await expect(service.markRead(RIDE_ID, DRIVER_ID)).resolves.toEqual({ updated: 2 });
    expect(readSpy).toHaveBeenCalledWith(RIDE_ID, DRIVER_ID);
  });
});
