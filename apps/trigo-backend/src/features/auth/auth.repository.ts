import { pool } from '../../shared/database/connection';
import { UserEntity } from './auth.types';
import { USER_ROLE } from '../../shared/constants/roles';
import { v4 as uuidv4 } from 'uuid';

export class AuthRepository {
  async findByEmail(email: string): Promise<UserEntity | null> {
    const res = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (res.rows.length === 0) return null;

    const row = res.rows[0];
    return {
      id: row.id,
      email: row.email,
      passwordHash: row.password_hash,
      firstName: row.first_name,
      lastName: row.last_name,
      phone: row.phone,
      role: row.role as USER_ROLE,
      profilePhotoUrl: row.profile_photo_url,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }

  async findById(id: string): Promise<UserEntity | null> {
    const res = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
    if (res.rows.length === 0) return null;

    const row = res.rows[0];
    return {
      id: row.id,
      email: row.email,
      passwordHash: row.password_hash,
      firstName: row.first_name,
      lastName: row.last_name,
      phone: row.phone,
      role: row.role as USER_ROLE,
      profilePhotoUrl: row.profile_photo_url,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }

  async createUser(user: Omit<UserEntity, 'id' | 'createdAt' | 'updatedAt'>): Promise<UserEntity> {
    const newId = uuidv4();
    const now = new Date();
    const newUser: UserEntity = {
      id: newId,
      ...user,
      createdAt: now,
      updatedAt: now,
    };

    await pool.query(
      `INSERT INTO users (id, email, password_hash, first_name, last_name, phone, role, profile_photo_url, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        newUser.id,
        newUser.email,
        newUser.passwordHash,
        newUser.firstName,
        newUser.lastName,
        newUser.phone,
        newUser.role,
        newUser.profilePhotoUrl || null,
        newUser.createdAt,
        newUser.updatedAt,
      ]
    );

    return newUser;
  }

  async updateUserRole(userId: string, newRole: USER_ROLE): Promise<void> {
    await pool.query('UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2', [newRole, userId]);
  }
}
