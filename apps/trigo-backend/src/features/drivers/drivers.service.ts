import { DriversRepository } from './drivers.repository';
import { DriverApplicationInput } from './drivers.types';
import { AuthRepository } from '../auth/auth.repository';
import { DRIVER_APPLICATION_STATUS, USER_ROLE } from '../../shared/constants/roles';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';

export class DriversService {
  private repository = new DriversRepository();
  private authRepository = new AuthRepository();

  async apply(userId: string, input: DriverApplicationInput) {
    const existing = await this.repository.findByUserId(userId);
    if (existing) {
      if (existing.applicationStatus === DRIVER_APPLICATION_STATUS.APPROVED) {
        throw new AppError('You are already an approved driver', 400, ERROR_CODES.CONFLICT);
      }
      if (existing.applicationStatus === DRIVER_APPLICATION_STATUS.PENDING) {
        throw new AppError('You already have a pending driver application', 400, ERROR_CODES.CONFLICT);
      }
      if (existing.applicationStatus === DRIVER_APPLICATION_STATUS.REVIEWING) {
        throw new AppError('Your application is currently being reviewed', 400, ERROR_CODES.CONFLICT);
      }
      // Rejected applications may be corrected and resubmitted
      return this.repository.replaceApplication(existing.id, input);
    }

    return this.repository.createApplication(userId, input);
  }

  async startReview(applicationId: string) {
    const app = await this.repository.findById(applicationId);
    if (!app) {
      throw new AppError('Driver application not found', 404, ERROR_CODES.NOT_FOUND);
    }
    if (app.applicationStatus !== DRIVER_APPLICATION_STATUS.PENDING) {
      throw new AppError(
        'Only pending applications can move to review',
        409,
        ERROR_CODES.CONFLICT,
      );
    }
    return this.repository.updateStatus(applicationId, DRIVER_APPLICATION_STATUS.REVIEWING);
  }

  async getOwnProfile(userId: string) {
    const profile = await this.repository.findByUserId(userId);
    if (!profile) {
      throw new AppError('Driver profile not found', 404, ERROR_CODES.NOT_FOUND);
    }
    return profile;
  }

  async getAllDrivers() {
    return this.repository.findAll();
  }

  // Online approved drivers — visible to any authenticated user so customers
  // can see who is nearby within the 3-minute freshness threshold
  async getOnlineDrivers(freshnessMinutes = 3) {
    return this.repository.findOnlineDrivers(freshnessMinutes);
  }

  async sweepStaleDrivers(thresholdMinutes = 3) {
    return this.repository.sweepStaleDrivers(thresholdMinutes);
  }

  async getDriverById(id: string) {
    const driver = await this.repository.findById(id);
    if (!driver) {
      throw new AppError('Driver not found', 404, ERROR_CODES.NOT_FOUND);
    }
    return driver;
  }

  async getApplications(status?: DRIVER_APPLICATION_STATUS) {
    return this.repository.findApplications(status);
  }

  async getApplicationById(applicationId: string) {
    const application = await this.repository.findById(applicationId);
    if (!application) {
      throw new AppError('Driver application not found', 404, ERROR_CODES.NOT_FOUND);
    }
    const documents = await this.repository.findDocumentsByProfileId(application.id);
    return { ...application, documents };
  }

  async approveApplication(applicationId: string) {
    const app = await this.repository.findById(applicationId);
    if (!app) {
      throw new AppError('Driver application not found', 404, ERROR_CODES.NOT_FOUND);
    }

    const updated = await this.repository.updateStatus(applicationId, DRIVER_APPLICATION_STATUS.APPROVED);
    // Upgrade user's role to driver
    await this.authRepository.updateUserRole(app.userId, USER_ROLE.DRIVER);

    return updated;
  }

  async rejectApplication(applicationId: string, reason: string) {
    const updated = await this.repository.updateStatus(applicationId, DRIVER_APPLICATION_STATUS.REJECTED, reason);
    if (!updated) {
      throw new AppError('Driver application not found', 404, ERROR_CODES.NOT_FOUND);
    }
    return updated;
  }

  async updateDriverStatus(driverId: string, status: DRIVER_APPLICATION_STATUS) {
    const updated = await this.repository.updateStatus(driverId, status);
    if (!updated) {
      throw new AppError('Driver not found', 404, ERROR_CODES.NOT_FOUND);
    }
    return updated;
  }

  async toggleOnlineStatus(userId: string, isOnline: boolean) {
    const profile = await this.repository.findByUserId(userId);
    if (!profile) {
      throw new AppError('Driver profile not found', 404, ERROR_CODES.NOT_FOUND);
    }
    if (profile.applicationStatus !== DRIVER_APPLICATION_STATUS.APPROVED) {
      throw new AppError('Only approved drivers can go online', 403, ERROR_CODES.FORBIDDEN);
    }

    await this.repository.setOnlineStatus(profile.id, isOnline);
    return { ...profile, isOnline };
  }
}
