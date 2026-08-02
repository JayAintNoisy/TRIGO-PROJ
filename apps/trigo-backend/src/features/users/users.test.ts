import { describe, it, expect, vi } from 'vitest';
import { UsersService } from './users.service';
import { UsersRepository } from './users.repository';
import { USER_ROLE } from '../../shared/constants/roles';

describe('UsersService', () => {
  const service = new UsersService();
  const mockUser = {
    id: '00000000-0000-0000-0000-000000000001',
    email: 'admin@trigo.ph',
    name: 'Admin User',
    phone: '09170000000',
    role: USER_ROLE.ADMIN,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  it('fetches all users', async () => {
    vi.spyOn(UsersRepository.prototype, 'findAll').mockResolvedValue([mockUser]);
    const users = await service.getAllUsers();
    expect(users.length).toBeGreaterThan(0);
  });

  it('fetches user by ID', async () => {
    vi.spyOn(UsersRepository.prototype, 'findById').mockResolvedValue(mockUser);
    const user = await service.getUserById('00000000-0000-0000-0000-000000000001');
    expect(user.email).toBe('admin@trigo.ph');
  });
});
