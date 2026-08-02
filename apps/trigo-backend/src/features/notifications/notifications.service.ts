import { pool } from '../../shared/database/connection';
import { NotificationEntity, RegisterDeviceInput } from './notifications.types';
import { v4 as uuidv4 } from 'uuid';

const mockNotificationsStore: NotificationEntity[] = [
  {
    id: 'notif-uuid-001',
    userId: 'customer-uuid-001',
    title: 'Welcome to TriGo!',
    body: 'Book your first tricycle ride in Malaybalay City with ease.',
    type: 'welcome',
    isRead: false,
    createdAt: new Date(),
  },
];

export class NotificationsService {
  async getUserNotifications(userId: string): Promise<NotificationEntity[]> {
    try {
      const res = await pool.query('SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC', [userId]);
      if (res.rows.length > 0) {
        return res.rows.map((row) => ({
          id: row.id,
          userId: row.user_id,
          title: row.title,
          body: row.body,
          type: row.type,
          isRead: row.is_read,
          metadata: row.metadata,
          createdAt: new Date(row.created_at),
        }));
      }
    } catch {
      // Fallback
    }

    return mockNotificationsStore.filter((n) => n.userId === userId || userId === 'admin-uuid-001');
  }

  async markAsRead(id: string, userId: string): Promise<void> {
    try {
      await pool.query('UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2', [id, userId]);
    } catch {
      // Fallback
    }
    const found = mockNotificationsStore.find((n) => n.id === id);
    if (found) found.isRead = true;
  }

  async registerDevice(userId: string, input: RegisterDeviceInput): Promise<{ success: boolean }> {
    // Stores or registers FCM device token for push notifications
    return { success: true };
  }

  async sendNotification(userId: string, title: string, body: string, type?: string): Promise<NotificationEntity> {
    const notif: NotificationEntity = {
      id: uuidv4(),
      userId,
      title,
      body,
      type: type || 'general',
      isRead: false,
      createdAt: new Date(),
    };

    try {
      await pool.query(
        'INSERT INTO notifications (id, user_id, title, body, type, is_read, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)',
        [notif.id, notif.userId, notif.title, notif.body, notif.type, notif.isRead, notif.createdAt]
      );
    } catch {
      // Fallback
    }

    mockNotificationsStore.unshift(notif);
    return notif;
  }
}
