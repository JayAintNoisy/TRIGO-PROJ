import { pool } from '../../shared/database/connection';
import { NotificationEntity } from './notifications.types';
import { v4 as uuidv4 } from 'uuid';

export class NotificationsRepository {
  async findAllByUserId(userId: string): Promise<NotificationEntity[]> {
    const res = await pool.query(
      'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC',
      [userId]
    );
    return res.rows.map(this.mapRowToEntity);
  }

  async create(notification: Omit<NotificationEntity, 'id' | 'createdAt'>): Promise<NotificationEntity> {
    const entity: NotificationEntity = {
      id: uuidv4(),
      ...notification,
      createdAt: new Date(),
    };

    await pool.query(
      'INSERT INTO notifications (id, user_id, title, body, type, is_read, metadata, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
      [entity.id, entity.userId, entity.title, entity.body, entity.type || null, entity.isRead, entity.metadata || null, entity.createdAt]
    );

    return entity;
  }

  async markAsRead(id: string, userId: string): Promise<void> {
    await pool.query('UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2', [id, userId]);
  }

  async upsertDeviceToken(userId: string, fcmToken: string, platform: string): Promise<void> {
    await pool.query(
      `INSERT INTO device_tokens (user_id, fcm_token, platform)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, platform) DO UPDATE SET fcm_token = EXCLUDED.fcm_token, updated_at = NOW()`,
      [userId, fcmToken, platform]
    );
  }

  // Resolves recipient user ids for an announcement audience
  async findUserIdsByAudience(audience: 'all' | 'drivers' | 'customers'): Promise<string[]> {
    let queryText = 'SELECT id FROM users';
    if (audience === 'drivers') queryText += " WHERE role = 'driver'";
    if (audience === 'customers') queryText += " WHERE role = 'customer'";

    const res = await pool.query(queryText);
    return res.rows.map((row: any) => row.id as string);
  }

  private mapRowToEntity(row: any): NotificationEntity {
    return {
      id: row.id,
      userId: row.user_id,
      title: row.title,
      body: row.body,
      type: row.type,
      isRead: row.is_read,
      metadata: row.metadata,
      createdAt: new Date(row.created_at),
    };
  }
}
