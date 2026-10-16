import { NotificationsRepository } from './notifications.repository';
import { NotificationEntity, RegisterDeviceInput } from './notifications.types';
import { NOTIFICATION_TYPE, NotificationType } from '../../shared/constants/notification-types';
import { paymentMethodLabel } from '../../shared/constants/payment-status';
import type { RideEntity } from '../rides/rides.types';

/** Who a ride notification is written for; drives the copy, not the routing. */
export type RideAudience = 'passenger' | 'driver';

/**
 * Every notification the platform writes.
 *
 * Ride events call the typed helpers below instead of `sendNotification`
 * directly so the wording, type and metadata stay in one place.
 */
export class NotificationsService {
  private repository = new NotificationsRepository();

  async getUserNotifications(userId: string): Promise<NotificationEntity[]> {
    return this.repository.findAllByUserId(userId);
  }

  async getUnreadCount(userId: string): Promise<{ count: number }> {
    return { count: await this.repository.countUnreadByUserId(userId) };
  }

  async markAsRead(id: string, userId: string): Promise<void> {
    await this.repository.markAsRead(id, userId);
  }

  // Persists the FCM device token; push delivery itself is a future enhancement
  async registerDevice(userId: string, input: RegisterDeviceInput): Promise<{ success: boolean }> {
    await this.repository.upsertDeviceToken(userId, input.fcmToken, input.platform);
    return { success: true };
  }

  async sendNotification(
    userId: string,
    title: string,
    body: string,
    type: NotificationType | string = 'general',
    metadata?: Record<string, any>
  ): Promise<NotificationEntity> {
    return this.repository.create({
      userId,
      title,
      body,
      type,
      isRead: false,
      metadata: metadata ?? null,
    });
  }

  /**
   * Tells every driver who could actually accept this ride that it exists.
   * Returns how many were notified; zero is normal outside service hours.
   */
  async notifyNewRideRequest(ride: RideEntity): Promise<number> {
    const driverIds = await this.repository.findOnlineDriverUserIdsByMunicipality(
      ride.municipalityId
    );

    const body = `${ride.pickupAddress ?? 'Pickup'} → ${ride.dropoffAddress ?? 'Drop-off'} · ${this.fare(ride)}`;
    for (const driverId of driverIds) {
      await this.sendNotification(driverId, 'New ride request', body, NOTIFICATION_TYPE.RIDE_REQUEST, {
        rideId: ride.id,
        pickupAddress: ride.pickupAddress ?? null,
        dropoffAddress: ride.dropoffAddress ?? null,
        fare: ride.fareEstimate,
      });
    }

    return driverIds.length;
  }

  async notifyRideStarted(ride: RideEntity): Promise<void> {
    const body = `You started the trip to ${ride.dropoffAddress ?? 'the destination'}`;
    if (ride.customerId) {
      await this.sendNotification(
        ride.customerId,
        'Trip started',
        `Your driver has started the trip to ${ride.dropoffAddress ?? 'your destination'}`,
        NOTIFICATION_TYPE.RIDE_STARTED,
        { rideId: ride.id }
      );
    }
    if (ride.driverId) {
      await this.sendNotification(ride.driverId, 'Trip started', body, NOTIFICATION_TYPE.RIDE_STARTED, {
        rideId: ride.id,
      });
    }
  }

  async notifyRideCompleted(ride: RideEntity, audience: RideAudience): Promise<void> {
    const userId = audience === 'passenger' ? ride.customerId : ride.driverId;
    if (!userId) return;

    const body =
      audience === 'passenger'
        ? `You have arrived at ${ride.dropoffAddress ?? 'your destination'} · ${this.fare(ride)}`
        : `Trip to ${ride.dropoffAddress ?? 'the destination'} completed · ${this.fare(ride)}`;

    await this.sendNotification(userId, 'Ride completed', body, NOTIFICATION_TYPE.RIDE_COMPLETED, {
      rideId: ride.id,
      fare: ride.fareFinal ?? ride.fareEstimate,
    });
  }

  async notifyRideCancelled(ride: RideEntity, cancelledBy: 'customer' | 'driver'): Promise<void> {
    // The party who did not cancel is the one who needs to know.
    const userId = cancelledBy === 'customer' ? ride.driverId : ride.customerId;
    if (!userId) return;

    await this.sendNotification(
      userId,
      'Ride cancelled',
      cancelledBy === 'customer' ? 'The passenger cancelled this ride' : 'The driver cancelled this ride',
      NOTIFICATION_TYPE.RIDE_CANCELLED,
      { rideId: ride.id }
    );
  }

  async notifyPaymentSent(ride: RideEntity, method: string): Promise<void> {
    if (!ride.customerId) return;
    await this.sendNotification(
      ride.customerId,
      'Payment sent',
      `${this.fare(ride)} sent via ${paymentMethodLabel(method)}`,
      NOTIFICATION_TYPE.PAYMENT_SENT,
      { rideId: ride.id, method, amount: ride.fareFinal ?? ride.fareEstimate }
    );
  }

  async notifyPaymentReceived(ride: RideEntity, method: string): Promise<void> {
    if (!ride.driverId) return;
    await this.sendNotification(
      ride.driverId,
      'Payment received',
      `${this.fare(ride)} received via ${paymentMethodLabel(method)}`,
      NOTIFICATION_TYPE.PAYMENT_RECEIVED,
      { rideId: ride.id, method, amount: ride.fareFinal ?? ride.fareEstimate }
    );
  }

  /** Alerts the other party that a chat message arrived. */
  async notifyNewMessage(ride: RideEntity, sender: RideAudience, preview: string): Promise<void> {
    const userId = sender === 'passenger' ? ride.driverId : ride.customerId;
    if (!userId) return;

    const senderName =
      (sender === 'passenger'
        ? ride.customerName
        : ride.driverName) ?? (sender === 'passenger' ? 'Your passenger' : 'Your driver');

    const trimmed = preview.length > 120 ? `${preview.slice(0, 117)}...` : preview;
    await this.sendNotification(
      userId,
      `New message from ${senderName}`,
      trimmed,
      NOTIFICATION_TYPE.MESSAGE,
      { rideId: ride.id, chat: true }
    );
  }

  // Admin announcement broadcast to an audience segment
  async broadcast(title: string, body: string, audience: 'all' | 'drivers' | 'customers'): Promise<{ recipientCount: number }> {
    const userIds = await this.repository.findUserIdsByAudience(audience);
    for (const userId of userIds) {
      await this.repository.create({
        userId,
        title,
        body,
        type: 'announcement',
        isRead: false,
        metadata: { audience },
      });
    }
    return { recipientCount: userIds.length };
  }

  private fare(ride: RideEntity): string {
    const amount = ride.fareFinal ?? ride.fareEstimate ?? 0;
    return `\u20B1${Number(amount).toFixed(0)}`;
  }
}
