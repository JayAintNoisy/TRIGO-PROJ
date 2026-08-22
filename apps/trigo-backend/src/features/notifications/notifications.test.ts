import { describe, it, expect, vi, beforeEach } from 'vitest';
import { NotificationsService } from './notifications.service';
import { NotificationsRepository } from './notifications.repository';
import { NotificationEntity } from './notifications.types';

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
});
