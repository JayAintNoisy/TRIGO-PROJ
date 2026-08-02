import { UsersRepository } from './users.repository';
import { UpdateProfileInput } from './users.types';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';

export class UsersService {
  private repository = new UsersRepository();

  async getAllUsers() {
    return this.repository.findAll();
  }

  async getUserById(id: string) {
    const user = await this.repository.findById(id);
    if (!user) {
      throw new AppError('User not found', 404, ERROR_CODES.NOT_FOUND);
    }
    return user;
  }

  async updateProfile(id: string, input: UpdateProfileInput) {
    const updated = await this.repository.updateProfile(id, input);
    if (!updated) {
      throw new AppError('User not found', 404, ERROR_CODES.NOT_FOUND);
    }
    return updated;
  }
}
