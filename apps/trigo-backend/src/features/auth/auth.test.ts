import { describe, it, expect, vi } from 'vitest';
import { AuthService } from './auth.service';
import { AuthRepository } from './auth.repository';
import { USER_ROLE } from '../../shared/constants/roles';
import bcrypt from 'bcryptjs';

describe('AuthService', () => {
  const authService = new AuthService();

  it('registers a new user and returns tokens', async () => {
    const testEmail = `test_${Date.now()}@trigo.ph`;
    vi.spyOn(AuthRepository.prototype, 'findByEmail').mockResolvedValue(null);
    vi.spyOn(AuthRepository.prototype, 'createUser').mockImplementation(async (user) => ({
      id: '00000000-0000-0000-0000-000000000003',
      ...user,
      createdAt: new Date(),
      updatedAt: new Date(),
    }));

    const res = await authService.register({
      email: testEmail,
      password: 'password123',
      name: 'Test User',
      phone: '+639123456789',
      role: USER_ROLE.CUSTOMER,
    });

    expect(res.accessToken).toBeDefined();
    expect(res.refreshToken).toBeDefined();
    expect(res.user.email).toBe(testEmail);
  });

  it('logins an existing user', async () => {
    vi.spyOn(AuthRepository.prototype, 'findByEmail').mockResolvedValue({
      id: '00000000-0000-0000-0000-000000000003',
      email: 'customer@trigo.ph',
      passwordHash: bcrypt.hashSync('customer123', 10),
      name: 'Maria Clara',
      phone: '09173334444',
      role: USER_ROLE.CUSTOMER,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const res = await authService.login({
      email: 'customer@trigo.ph',
      password: 'customer123',
    });

    expect(res.accessToken).toBeDefined();
    expect(res.user.role).toBe(USER_ROLE.CUSTOMER);
  });
});
