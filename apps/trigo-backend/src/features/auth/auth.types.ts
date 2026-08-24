import { USER_ROLE } from '../../shared/constants/roles';

export interface UserEntity {
  id: string;
  email: string;
  passwordHash: string;
  firstName: string;
  lastName: string;
  phone: string;
  role: USER_ROLE;
  driverIntent: boolean;
  profilePhotoUrl?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface RegisterInput {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  phone: string;
  asDriver?: boolean;
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
    firstName: string;
    lastName: string;
    phone: string;
    role: USER_ROLE;
    driverIntent: boolean;
    profilePhotoUrl?: string | null;
    driverProfile?: any;
  };
}
