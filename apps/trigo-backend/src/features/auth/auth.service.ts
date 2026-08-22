import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { AuthRepository } from './auth.repository';
import { RegisterInput, LoginInput, AuthResponse } from './auth.types';
import { DriversRepository } from '../drivers/drivers.repository';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';
import { env } from '../../env';
import { USER_ROLE } from '../../shared/constants/roles';

export class AuthService {
  private authRepository = new AuthRepository();
  private driversRepository = new DriversRepository();

  async register(input: RegisterInput): Promise<AuthResponse> {
    const existing = await this.authRepository.findByEmail(input.email);
    if (existing) {
      throw new AppError('Email address is already registered', 400, ERROR_CODES.CONFLICT);
    }

    const passwordHash = await bcrypt.hash(input.password, 10);
    const user = await this.authRepository.createUser({
      email: input.email.toLowerCase(),
      passwordHash,
      name: input.name,
      phone: input.phone,
      // Public registration always starts as customer; drivers upgrade only
      // through the application approval flow
      role: USER_ROLE.CUSTOMER,
    });

    return this.generateTokensAndResponse(user);
  }

  async login(input: LoginInput): Promise<AuthResponse> {
    const user = await this.authRepository.findByEmail(input.email);
    if (!user) {
      throw new AppError('Invalid email or password', 401, ERROR_CODES.UNAUTHORIZED);
    }

    const validPassword = await bcrypt.compare(input.password, user.passwordHash);
    if (!validPassword) {
      throw new AppError('Invalid email or password', 401, ERROR_CODES.UNAUTHORIZED);
    }

    return this.generateTokensAndResponse(user);
  }

  async refreshToken(refreshToken: string): Promise<{ accessToken: string }> {
    try {
      const payload = jwt.verify(refreshToken, env.JWT_REFRESH_SECRET) as any;
      const user = await this.authRepository.findById(payload.id);
      if (!user) {
        throw new AppError('User not found', 401, ERROR_CODES.UNAUTHORIZED);
      }

      const accessToken = jwt.sign(
        { id: user.id, email: user.email, role: user.role, name: user.name },
        env.JWT_SECRET,
        { expiresIn: '1d' }
      );

      return { accessToken };
    } catch {
      throw new AppError('Invalid refresh token', 401, ERROR_CODES.UNAUTHORIZED);
    }
  }

  async getCurrentUser(userId: string) {
    const user = await this.authRepository.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404, ERROR_CODES.NOT_FOUND);
    }
    const driverProfile = await this.driversRepository.findByUserId(userId);
    return {
      id: user.id,
      email: user.email,
      name: user.name,
      phone: user.phone,
      role: user.role,
      profilePhotoUrl: user.profilePhotoUrl,
      driverProfile: driverProfile || null,
    };
  }

  // Stateless JWTs cannot be revoked server-side; the client discards its tokens
  async logout(): Promise<{ success: boolean }> {
    return { success: true };
  }

  private generateTokensAndResponse(user: any): AuthResponse {
    const payload = {
      id: user.id,
      email: user.email,
      role: user.role,
      name: user.name,
    };

    const accessToken = jwt.sign(payload, env.JWT_SECRET, { expiresIn: '1d' });
    const refreshToken = jwt.sign(payload, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        phone: user.phone,
        role: user.role,
        profilePhotoUrl: user.profilePhotoUrl,
      },
    };
  }
}
