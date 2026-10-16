import { describe, it, expect, vi, beforeEach } from 'vitest';
import { NotificationsService } from './notifications.service';
import { NotificationsRepository } from './notifications.repository';
import { NotificationEntity } from './notifications.types';
import { NOTIFICATION_TYPE } from '../../shared/constants/notification-types';
import { PAYMENT_METHOD } from '../../shared/constants/payment-status';
import { RIDE_STATUS } from '../../shared/constants/ride-status';

const mockRide = (overrides: Record<string, unknown> = {}) => ({
  id: 'ride-uuid-001',
  customerId: 'customer-uuid-001',
  driverId: 'driver-uuid-001',
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
  createdAt: new Date(),
  updatedAt: new Date(),
  ...overrides,
}) as any;

describe('NotificationsService', () => {
  const service = new NotificationsService();

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('sends and fetches notification for user', async () => {
    const sent: NotificationEntity = {
      id: 'notif-1',
      userId: 'customer-uuid-001',
      title: 'Test Notif',
      body: 'Test Body',
      type: 'general',
      isRead: false,
      createdAt: new Date(),
    };

    vi.spyOn(NotificationsRepository.prototype, 'create').mockResolvedValue(sent);
    vi.spyOn(NotificationsRepository.prototype, 'findAllByUserId').mockResolvedValue([sent]);

    await service.sendNotification('customer-uuid-001', 'Test Notif', 'Test Body');
    const list = await service.getUserNotifications('customer-uuid-001');
    expect(list.length).toBeGreaterThan(0);
    expect(list[0].title).toBe('Test Notif');
  });

  it('registers a device token', async () => {
    vi.spyOn(NotificationsRepository.prototype, 'upsertDeviceToken').mockResolvedValue(undefined);

    const result = await service.registerDevice('user-1', {
      fcmToken: 'fcm-token-abcdef123456',
      platform: 'android',
    });
    expect(result.success).toBe(true);
  });

  it('broadcasts to the resolved audience', async () => {
    vi.spyOn(NotificationsRepository.prototype, 'findUserIdsByAudience').mockResolvedValue(['u1', 'u2']);
    const createSpy = vi.spyOn(NotificationsRepository.prototype, 'create').mockImplementation(async (n) => ({
      id: 'notif-x',
      ...n,
      createdAt: new Date(),
    }));

    const result = await service.broadcast('Maintenance', 'Downtime tonight', 'drivers');
    expect(result.recipientCount).toBe(2);
    expect(createSpy).toHaveBeenCalledTimes(2);
  });

  it('reports the unread count', async () => {
    vi.spyOn(NotificationsRepository.prototype, 'countUnreadByUserId').mockResolvedValue(3);

    await expect(service.getUnreadCount('user-1')).resolves.toEqual({ count: 3 });
  });
});

describe('NotificationsService ride events', () => {
  const service = new NotificationsService();

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  const spyOnCreate = () =>
    vi.spyOn(NotificationsRepository.prototype, 'create').mockImplementation(async (n) => ({
      id: `notif-${Math.random()}`,
      ...n,
      createdAt: new Date(),
    }));

  it('offers a new request to every online driver in the municipality', async () => {
    vi.spyOn(NotificationsRepository.prototype, 'findOnlineDriverUserIdsByMunicipality')
      .mockResolvedValue(['driver-1', 'driver-2']);
    const createSpy = spyOnCreate();

    const notified = await service.notifyNewRideRequest(mockRide());

    expect(notified).toBe(2);
    expect(createSpy).toHaveBeenCalledTimes(2);
    expect(createSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'driver-1',
        title: 'New ride request',
        type: NOTIFICATION_TYPE.RIDE_REQUEST,
        metadata: expect.objectContaining({ rideId: 'ride-uuid-001' }),
      })
    );
    expect(createSpy.mock.calls[0][0].body).toContain('\u20B185');
  });

  it('writes nothing when no driver is online', async () => {
    vi.spyOn(NotificationsRepository.prototype, 'findOnlineDriverUserIdsByMunicipality')
      .mockResolvedValue([]);
    const createSpy = spyOnCreate();

    await expect(service.notifyNewRideRequest(mockRide())).resolves.toBe(0);
    expect(createSpy).not.toHaveBeenCalled();
  });

  it('tells both sides when the trip starts', async () => {
    const createSpy = spyOnCreate();

    await service.notifyRideStarted(mockRide());

    expect(createSpy).toHaveBeenCalledTimes(2);
    const recipients = createSpy.mock.calls.map(([n]) => n.userId);
    expect(recipients).toEqual(expect.arrayContaining(['customer-uuid-001', 'driver-uuid-001']));
    expect(createSpy.mock.calls.every(([n]) => n.type === NOTIFICATION_TYPE.RIDE_STARTED)).toBe(true);
  });

  it('writes role-appropriate completion copy for both sides', async () => {
    const createSpy = spyOnCreate();

    await service.notifyRideCompleted(mockRide(), 'passenger');
    await service.notifyRideCompleted(mockRide(), 'driver');

    expect(createSpy).toHaveBeenCalledTimes(2);
    expect(createSpy.mock.calls[0][0]).toMatchObject({
      userId: 'customer-uuid-001',
      title: 'Ride completed',
      type: NOTIFICATION_TYPE.RIDE_COMPLETED,
    });
    expect(createSpy.mock.calls[0][0].body).toContain('You have arrived');
    expect(createSpy.mock.calls[1][0].body).toContain('completed');
  });

  it('labels the payment method on the sent and received pair', async () => {
    const createSpy = spyOnCreate();

    await service.notifyPaymentSent(mockRide(), PAYMENT_METHOD.GCASH);
    await service.notifyPaymentReceived(mockRide(), PAYMENT_METHOD.GCASH);

    expect(createSpy.mock.calls[0][0]).toMatchObject({
      userId: 'customer-uuid-001',
      title: 'Payment sent',
      type: NOTIFICATION_TYPE.PAYMENT_SENT,
      metadata: expect.objectContaining({ method: 'gcash' }),
    });
    expect(createSpy.mock.calls[0][0].body).toContain('GCash');
    expect(createSpy.mock.calls[1][0]).toMatchObject({
      userId: 'driver-uuid-001',
      title: 'Payment received',
      type: NOTIFICATION_TYPE.PAYMENT_RECEIVED,
    });
  });

  it('warns only the party who did not cancel', async () => {
    const createSpy = spyOnCreate();

    await service.notifyRideCancelled(mockRide({ status: RIDE_STATUS.ACCEPTED }), 'customer');

    expect(createSpy).toHaveBeenCalledTimes(1);
    expect(createSpy.mock.calls[0][0]).toMatchObject({
      userId: 'driver-uuid-001',
      type: NOTIFICATION_TYPE.RIDE_CANCELLED,
    });
  });

  it('alerts the other party about a new message, shortening long bodies', async () => {
    const createSpy = spyOnCreate();
    const long = 'x'.repeat(200);

    await service.notifyNewMessage(mockRide(), 'passenger', long);

    expect(createSpy).toHaveBeenCalledTimes(1);
    expect(createSpy.mock.calls[0][0]).toMatchObject({
      userId: 'driver-uuid-001',
      title: 'New message from Maria Clara',
      type: NOTIFICATION_TYPE.MESSAGE,
      metadata: expect.objectContaining({ chat: true, rideId: 'ride-uuid-001' }),
    });
    expect(createSpy.mock.calls[0][0].body.length).toBeLessThanOrEqual(120);
  });
});
