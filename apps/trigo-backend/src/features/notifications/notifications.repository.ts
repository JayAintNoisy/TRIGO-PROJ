import { pool } from '../../shared/database/connection';
import { NotificationEntity } from './notifications.types';
import { v4 as uuidv4 } from 'uuid';

export class NotificationsRepository {
  async findAllByUserId(userId: string): Promise<NotificationEntity[]> {
    // Bounded page: ride events add several rows per trip.
    const res = await pool.query(
      'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 100',
      [userId]
    );
    return res.rows.map(this.mapRowToEntity);
  }

  async countUnreadByUserId(userId: string): Promise<number> {
    const res = await pool.query(
      'SELECT COUNT(*)::int AS count FROM notifications WHERE user_id = $1 AND is_read = false',
      [userId]
    );
    return res.rows[0]?.count ?? 0;
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

  /**
   * Drivers who could actually see and accept a request in [municipalityId]:
   * approved, online, and still inside the same freshness window the
   * `/drivers/online` list uses.
   */
  async findOnlineDriverUserIdsByMunicipality(
    municipalityId: string,
    freshnessMinutes = 3
  ): Promise<string[]> {
    const res = await pool.query(
      `SELECT dp.user_id
       FROM driver_profiles dp
       WHERE dp.application_status = 'approved'
         AND dp.is_online = true
         AND dp.municipality_id = $1
         AND dp.updated_at >= NOW() - ($2 || ' minutes')::INTERVAL`,
      [municipalityId, freshnessMinutes]
    );
    return res.rows.map((row: any) => row.user_id as string);
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
