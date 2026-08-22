import { USER_ROLE } from '../../shared/constants/roles';

export interface UserEntity {
  id: string;
  email: string;
  passwordHash: string;
  name: string;
  phone: string;
  role: USER_ROLE;
  profilePhotoUrl?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface RegisterInput {
  email: string;
  password: string;
  name: string;
  phone: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    email: string;
    name: string;
    phone: string;
    role: USER_ROLE;
    profilePhotoUrl?: string | null;
    driverProfile?: any;
  };
}
