import { MessagingRepository } from './messaging.repository';
import { RideMessageEntity } from './messaging.types';
import { RidesRepository } from '../rides/rides.repository';
import { NotificationsService, RideAudience } from '../notifications/notifications.service';
import { RIDE_STATUS } from '../../shared/constants/ride-status';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';
import type { RideEntity } from '../rides/rides.types';

/** How long a finished ride's thread stays writable, for "I left my bag" cases. */
export const CHAT_WRITABLE_AFTER_COMPLETION_HOURS = 24;

const ACTIVE_CHAT_STATUSES: RIDE_STATUS[] = [
  RIDE_STATUS.ACCEPTED,
  RIDE_STATUS.DRIVER_ARRIVING,
  RIDE_STATUS.IN_PROGRESS,
];

/**
 * In-app chat between the passenger and the driver of one ride.
 *
 * It supplements the phone call and SMS actions rather than replacing them, so
 * it is scoped strictly to a ride's two participants and stops accepting new
 * messages once the trip is long over.
 */
export class MessagingService {
  private repository = new MessagingRepository();
  private ridesRepository = new RidesRepository();
  private notificationsService = new NotificationsService();

  async listMessages(rideId: string, userId: string): Promise<RideMessageEntity[]> {
    await this.getParticipantRide(rideId, userId);
    return this.repository.findByRideId(rideId);
  }

  async sendMessage(rideId: string, userId: string, body: string): Promise<RideMessageEntity> {
    const ride = await this.getParticipantRide(rideId, userId);
    this.assertWritable(ride);

    const trimmed = body.trim();
    if (!trimmed) {
      throw new AppError('Message cannot be empty', 400, ERROR_CODES.VALIDATION_ERROR);
    }

    const message = await this.repository.create(rideId, userId, trimmed);

    // The message is delivered even if the alert row cannot be written.
    try {
      const sender: RideAudience = userId === ride.driverId ? 'driver' : 'passenger';
      await this.notificationsService.notifyNewMessage(ride, sender, trimmed);
    } catch (_) {
      // Non-fatal: the recipient still sees the message on the next poll.
    }

    return message;
  }

  async markRead(rideId: string, userId: string): Promise<{ updated: number }> {
    await this.getParticipantRide(rideId, userId);
    return { updated: await this.repository.markThreadRead(rideId, userId) };
  }

  /**
   * Loads the ride and proves the caller is one of its two participants.
   * Mirrors the access rule used for reading a ride.
   */
  private async getParticipantRide(rideId: string, userId: string): Promise<RideEntity> {
    const ride = await this.ridesRepository.findById(rideId);
    if (!ride) {
      throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);
    }
    if (ride.customerId !== userId && ride.driverId !== userId) {
      throw new AppError('Access denied to this conversation', 403, ERROR_CODES.FORBIDDEN);
    }
    return ride;
  }

  private assertWritable(ride: RideEntity): void {
    if (!ride.driverId) {
      throw new AppError(
        'You can only message once a driver has accepted this ride',
        400,
        ERROR_CODES.RIDE_INVALID_STATE
      );
    }
    if (ride.status === RIDE_STATUS.CANCELLED) {
      throw new AppError('This ride was cancelled', 400, ERROR_CODES.RIDE_INVALID_STATE);
    }
    if (ACTIVE_CHAT_STATUSES.includes(ride.status)) return;

    if (ride.status === RIDE_STATUS.COMPLETED && ride.completedAt) {
      const closesAt = new Date(ride.completedAt);
      closesAt.setHours(closesAt.getHours() + CHAT_WRITABLE_AFTER_COMPLETION_HOURS);
      if (new Date() <= closesAt) return;
    }

    throw new AppError('This ride has ended', 400, ERROR_CODES.RIDE_INVALID_STATE);
  }
}
