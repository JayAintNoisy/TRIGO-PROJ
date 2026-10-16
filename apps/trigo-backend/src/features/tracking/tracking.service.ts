import { TrackingRepository } from './tracking.repository';
import { DriverLocationUpdate } from './tracking.types';

export class TrackingService {
  private repository = new TrackingRepository();

  async recordLocation(driverUserId: string, update: DriverLocationUpdate) {
    await this.repository.recordLocation(driverUserId, update);
    return { success: true };
  }

  /// The live fleet, optionally scoped to one service area.
  async getActiveDrivers(municipalityId?: string) {
    return this.repository.getActiveDrivers(municipalityId);
  }
}
