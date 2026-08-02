import { USER_ROLE } from '../../shared/constants/roles';

export interface UserDetail {
  id: string;
  email: string;
  name: string;
  phone: string;
  role: USER_ROLE;
  profilePhotoUrl?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface UpdateProfileInput {
  name?: string;
  phone?: string;
  profilePhotoUrl?: string;
}
