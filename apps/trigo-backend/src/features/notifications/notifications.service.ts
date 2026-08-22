import { NotificationsRepository } from './notifications.repository';
import { NotificationEntity, RegisterDeviceInput } from './notifications.types';

export class NotificationsService {
  private repository = new NotificationsRepository();

  async getUserNotifications(userId: string): Promise<NotificationEntity[]> {
    return this.repository.findAllByUserId(userId);
  }

  async markAsRead(id: string, userId: string): Promise<void> {
    await this.repository.markAsRead(id, userId);
  }

  // Persists the FCM device token; push delivery itself is a future enhancement
  async registerDevice(userId: string, input: RegisterDeviceInput): Promise<{ success: boolean }> {
    await this.repository.upsertDeviceToken(userId, input.fcmToken, input.platform);
    return { success: true };
  }

  async sendNotification(userId: string, title: string, body: string, type?: string): Promise<NotificationEntity> {
    return this.repository.create({ userId, title, body, type: type || 'general', isRead: false });
  }

  // Admin announcement broadcast to an audience segment
  async broadcast(title: string, body: string, audience: 'all' | 'drivers' | 'customers'): Promise<{ recipientCount: number }> {
    const userIds = await this.repository.findUserIdsByAudience(audience);
    for (const userId of userIds) {
      await this.repository.create({
        userId,
        title,
        body,
        type: 'announcement',
        isRead: false,
        metadata: { audience },
      });
    }
    return { recipientCount: userIds.length };
  }
}
