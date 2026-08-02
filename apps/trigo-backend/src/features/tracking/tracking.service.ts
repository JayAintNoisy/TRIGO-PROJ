import { TrackingRepository } from './tracking.repository';
import { DriverLocationUpdate } from './tracking.types';

export class TrackingService {
  private repository = new TrackingRepository();

  async recordLocation(driverUserId: string, update: DriverLocationUpdate) {
    await this.repository.recordLocation(driverUserId, update);
    return { success: true };
  }

  async getActiveDrivers() {
    return this.repository.getActiveDrivers();
  }
}
