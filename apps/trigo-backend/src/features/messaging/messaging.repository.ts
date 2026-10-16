import { pool } from '../../shared/database/connection';
import { RideMessageEntity } from './messaging.types';
import { v4 as uuidv4 } from 'uuid';

const MESSAGE_SELECT = `
  SELECT rm.*,
         CONCAT_WS(' ', u.first_name, u.last_name) AS sender_name
  FROM ride_messages rm
  LEFT JOIN users u ON u.id = rm.sender_id
`;

export class MessagingRepository {
  async create(rideId: string, senderId: string, body: string): Promise<RideMessageEntity> {
    const newId = uuidv4();
    await pool.query(
      'INSERT INTO ride_messages (id, ride_id, sender_id, body, created_at) VALUES ($1, $2, $3, $4, NOW())',
      [newId, rideId, senderId, body]
    );

    const created = await this.findById(newId);
    return created!;
  }

  async findById(id: string): Promise<RideMessageEntity | null> {
    const res = await pool.query(`${MESSAGE_SELECT} WHERE rm.id = $1`, [id]);
    if (res.rows.length === 0) return null;
    return this.mapRowToEntity(res.rows[0]);
  }

  /** Full thread, oldest first, so the client can render it top-to-bottom. */
  async findByRideId(rideId: string): Promise<RideMessageEntity[]> {
    const res = await pool.query(
      `${MESSAGE_SELECT} WHERE rm.ride_id = $1 ORDER BY rm.created_at ASC`,
      [rideId]
    );
    return res.rows.map(this.mapRowToEntity);
  }

  /** Marks everything the reader has received, leaving their own sends alone. */
  async markThreadRead(rideId: string, readerId: string): Promise<number> {
    const res = await pool.query(
      'UPDATE ride_messages SET read_at = NOW() WHERE ride_id = $1 AND sender_id <> $2 AND read_at IS NULL',
      [rideId, readerId]
    );
    return res.rowCount || 0;
  }

  private mapRowToEntity(row: any): RideMessageEntity {
    return {
      id: row.id,
      rideId: row.ride_id,
      senderId: row.sender_id,
      body: row.body,
      readAt: row.read_at ? new Date(row.read_at) : null,
      createdAt: new Date(row.created_at),
      senderName: row.sender_name || undefined,
    };
  }
}
