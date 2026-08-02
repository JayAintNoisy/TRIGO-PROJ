import { describe, it, expect } from 'vitest';
import { NotificationsService } from './notifications.service';

describe('NotificationsService', () => {
  const service = new NotificationsService();

  it('sends and fetches notification for user', async () => {
    await service.sendNotification('customer-uuid-001', 'Test Notif', 'Test Body');
    const list = await service.getUserNotifications('customer-uuid-001');
    expect(list.length).toBeGreaterThan(0);
  });
});
