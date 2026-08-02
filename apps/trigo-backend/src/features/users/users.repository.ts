import { pool } from '../../shared/database/connection';
import { UserDetail, UpdateProfileInput } from './users.types';
import { USER_ROLE } from '../../shared/constants/roles';

export class UsersRepository {
  async findAll(): Promise<UserDetail[]> {
    const res = await pool.query('SELECT id, email, name, phone, role, profile_photo_url, created_at, updated_at FROM users ORDER BY created_at DESC');
    return res.rows.map((row) => ({
      id: row.id,
      email: row.email,
      name: row.name,
      phone: row.phone,
      role: row.role as USER_ROLE,
      profilePhotoUrl: row.profile_photo_url,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    }));
  }

  async findById(id: string): Promise<UserDetail | null> {
    const res = await pool.query('SELECT id, email, name, phone, role, profile_photo_url, created_at, updated_at FROM users WHERE id = $1', [id]);
    if (res.rows.length === 0) return null;

    const row = res.rows[0];
    return {
      id: row.id,
      email: row.email,
      name: row.name,
      phone: row.phone,
      role: row.role as USER_ROLE,
      profilePhotoUrl: row.profile_photo_url,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }

  async updateProfile(id: string, input: UpdateProfileInput): Promise<UserDetail | null> {
    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (input.name) {
      fields.push(`name = $${idx++}`);
      values.push(input.name);
    }
    if (input.phone) {
      fields.push(`phone = $${idx++}`);
      values.push(input.phone);
    }
    if (input.profilePhotoUrl !== undefined) {
      fields.push(`profile_photo_url = $${idx++}`);
      values.push(input.profilePhotoUrl);
    }

    if (fields.length > 0) {
      fields.push(`updated_at = NOW()`);
      values.push(id);
      await pool.query(`UPDATE users SET ${fields.join(', ')} WHERE id = $${idx}`, values);
    }

    return this.findById(id);
  }
}
