import { RidesRepository } from './rides.repository';
import { RideEntity } from './rides.types';
import { MunicipalitiesService } from '../municipalities/municipalities.service';
import { DriversRepository } from '../drivers/drivers.repository';
import { PaymentsRepository } from '../payments/payments.repository';
import { DriverPaymentMethodsService } from '../payments/driver-payment-methods.service';
import { NotificationsService } from '../notifications/notifications.service';
import { TrackingRepository } from '../tracking/tracking.repository';
import { CreateRideInput, RateRideInput } from './rides.types';
import { calculateFare } from '../../shared/utils/calculate-fare';
import { RIDE_STATUS } from '../../shared/constants/ride-status';
import {
  RATING_EDIT_WINDOW_HOURS,
  isWithinRatingEditWindow,
} from '../../shared/constants/rating';
import { USER_ROLE, DRIVER_APPLICATION_STATUS } from '../../shared/constants/roles';
import { PAYMENT_METHOD, PAYMENT_STATUS } from '../../shared/constants/payment-status';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';
import { logger } from '../../shared/logging/logger';

const ACTIVE_STATUSES = [RIDE_STATUS.ACCEPTED, RIDE_STATUS.DRIVER_ARRIVING, RIDE_STATUS.IN_PROGRESS];

export class RidesService {
  private repository = new RidesRepository();
  private municipalitiesService = new MunicipalitiesService();
  private driversRepository = new DriversRepository();
  private paymentsRepository = new PaymentsRepository();
  private driverPaymentMethodsService = new DriverPaymentMethodsService();
  private notificationsService = new NotificationsService();
  private trackingRepository = new TrackingRepository();

  async requestRide(customerId: string, input: CreateRideInput) {
    // 1. Verify jurisdiction limits for pickup & dropoff
    const pickupValid = await this.municipalitiesService.isWithinBoundary(input.municipalityId, input.pickupLat, input.pickupLng);
    const dropoffValid = await this.municipalitiesService.isWithinBoundary(input.municipalityId, input.dropoffLat, input.dropoffLng);

    if (!pickupValid || !dropoffValid) {
      throw new AppError(
        'Pickup or dropoff location is outside municipality jurisdiction boundary',
        400,
        ERROR_CODES.OUT_OF_BOUNDS
      );
    }

    // 2. Fetch municipality fare matrix
    const municipality = await this.municipalitiesService.getMunicipalityById(input.municipalityId);

    // 3. Calculate distance & fare estimate (honouring minimum fare and the
    //    10PM–4AM night surcharge configured per municipality)
    const fareResult = calculateFare({
      pickupLat: input.pickupLat,
      pickupLng: input.pickupLng,
      dropoffLat: input.dropoffLat,
      dropoffLng: input.dropoffLng,
      baseFare: municipality.baseFare,
      perKmRate: municipality.perKmRate,
    });

    let fareEstimate = fareResult.totalFare;
    const hour = new Date().getHours();
    if ((hour >= 22 || hour < 4) && municipality.nightSurcharge > 0) {
      fareEstimate += municipality.nightSurcharge;
    }
    fareEstimate = Math.max(fareEstimate, municipality.minFare);

    // 4. Create ride entity
    const ride = await this.repository.create({
      customerId,
      municipalityId: input.municipalityId,
      pickupLat: input.pickupLat,
      pickupLng: input.pickupLng,
      pickupAddress: input.pickupAddress || 'Selected Pickup Location',
      dropoffLat: input.dropoffLat,
      dropoffLng: input.dropoffLng,
      dropoffAddress: input.dropoffAddress || 'Selected Destination',
      status: RIDE_STATUS.REQUESTED,
      fareEstimate,
      distanceKm: fareResult.distanceKm,
    });

    // 5. Offer it to the drivers who could actually accept it
    await this.notify(() =>
      this.notificationsService.notifyNewRideRequest({
        ...ride,
        pickupAddress: ride.pickupAddress ?? input.pickupAddress,
        dropoffAddress: ride.dropoffAddress ?? input.dropoffAddress,
      })
    );

    return ride;
  }

  /**
   * Ride actions must never fail because an alert could not be written, so
   * notification work is best-effort and only logged.
   */
  private async notify(action: () => Promise<unknown>): Promise<void> {
    try {
      await action();
    } catch (error) {
      logger.warn('Ride notification failed', error as Error);
    }
  }

  async listRides(user: { id: string; role: USER_ROLE }, filterStatus?: RIDE_STATUS) {
    if (user.role === USER_ROLE.ADMIN) {
      return this.repository.findAll({ status: filterStatus });
    }
    if (user.role === USER_ROLE.DRIVER) {
      // rides.driver_id stores the users.id of the assigned driver
      return this.repository.findAll({ driverId: user.id, status: filterStatus });
    }
    return this.repository.findAll({ customerId: user.id, status: filterStatus });
  }

  // Open ride requests in the driver's municipality — polled by driver apps
  async listAvailableRides(driverUserId: string) {
    const profile = await this.driversRepository.findByUserId(driverUserId);
    if (!profile || profile.applicationStatus !== DRIVER_APPLICATION_STATUS.APPROVED) {
      throw new AppError('Only approved drivers can view available rides', 403, ERROR_CODES.FORBIDDEN);
    }
    return this.repository.findAll({
      status: RIDE_STATUS.REQUESTED,
      municipalityId: profile.municipalityId,
    });
  }

  async getRideById(id: string, userId: string, role: USER_ROLE) {
    const ride = await this.repository.findById(id);
    if (!ride) {
      throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);
    }
    if (role !== USER_ROLE.ADMIN && ride.customerId !== userId && ride.driverId !== userId) {
      throw new AppError('Access denied to this ride', 403, ERROR_CODES.FORBIDDEN);
    }
    return ride;
  }

  async acceptRide(rideId: string, driverUserId: string) {
    const driverProfile = await this.driversRepository.findByUserId(driverUserId);
    if (!driverProfile || driverProfile.applicationStatus !== DRIVER_APPLICATION_STATUS.APPROVED) {
      throw new AppError('Only approved drivers can accept rides', 403, ERROR_CODES.FORBIDDEN);
    }

    const ride = await this.repository.findById(rideId);
    if (!ride) {
      throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);
    }
    if (ride.status !== RIDE_STATUS.REQUESTED) {
      throw new AppError('Ride is no longer available for acceptance', 400, ERROR_CODES.RIDE_INVALID_STATE);
    }

    return this.repository.updateStatus(rideId, RIDE_STATUS.ACCEPTED, { driverId: driverUserId });
  }

  async markArrived(rideId: string, driverUserId: string) {
    const ride = await this.getAssignedRide(rideId, driverUserId);
    if (ride.status !== RIDE_STATUS.ACCEPTED) {
      throw new AppError('Driver can only arrive at accepted rides', 400, ERROR_CODES.RIDE_INVALID_STATE);
    }

    return this.repository.updateStatus(rideId, RIDE_STATUS.DRIVER_ARRIVING);
  }

  async startRide(rideId: string, driverUserId: string) {
    const ride = await this.getAssignedRide(rideId, driverUserId);
    if (ride.status !== RIDE_STATUS.DRIVER_ARRIVING) {
      throw new AppError('Ride can only start after the driver has arrived', 400, ERROR_CODES.RIDE_INVALID_STATE);
    }

    const started = await this.repository.updateStatus(rideId, RIDE_STATUS.IN_PROGRESS, {
      startedAt: new Date(),
    });

    // Both sides are told the trip is under way.
    await this.notify(() => this.notificationsService.notifyRideStarted(started ?? ride));

    return started;
  }

  async completeRide(rideId: string, driverUserId: string) {
    const ride = await this.getAssignedRide(rideId, driverUserId);
    if (ride.status !== RIDE_STATUS.IN_PROGRESS) {
      throw new AppError('Only rides currently in progress can be completed', 400, ERROR_CODES.RIDE_INVALID_STATE);
    }

    const completed = await this.repository.updateStatus(rideId, RIDE_STATUS.COMPLETED, {
      fareFinal: ride.fareEstimate,
      completedAt: new Date(),
    });

    // Record what the passenger chose (cash when they never chose or the
    // driver no longer accepts it) and bump driver stats
    const method = await this.resolveCompletedPaymentMethod(ride, driverUserId);
    await this.paymentsRepository.create(rideId, ride.fareEstimate, method, PAYMENT_STATUS.COMPLETED);
    await this.driversRepository.incrementTotalRides(driverUserId);

    // Completion and settlement alerts for both sides. The settled ride is
    // used so the copy carries the final fare.
    const settled = completed ?? ride;
    await this.notify(async () => {
      await this.notificationsService.notifyRideCompleted(settled, 'passenger');
      await this.notificationsService.notifyRideCompleted(settled, 'driver');
      await this.notificationsService.notifyPaymentSent(settled, method);
      await this.notificationsService.notifyPaymentReceived(settled, method);
    });

    return completed;
  }

  /**
   * Selects the payment method used by the passenger for this ride.
   *
   * Allowed only once a driver has accepted and before the trip finishes, and
   * only for a method that driver actually accepts (cash always qualifies).
   */
  async setRidePaymentMethod(rideId: string, customerId: string, method: PAYMENT_METHOD) {
    const ride = await this.repository.findById(rideId);
    if (!ride) throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);

    if (ride.customerId !== customerId) {
      throw new AppError('Only the passenger on this ride can choose the payment method', 403, ERROR_CODES.FORBIDDEN);
    }
    if (!ride.driverId) {
      throw new AppError('Choose a driver before selecting a payment method', 400, ERROR_CODES.RIDE_INVALID_STATE);
    }
    if (!ACTIVE_STATUSES.includes(ride.status)) {
      throw new AppError(
        'The payment method can only be chosen before the ride is completed',
        400,
        ERROR_CODES.RIDE_INVALID_STATE
      );
    }

    if (method !== PAYMENT_METHOD.CASH) {
      const accepted = await this.driverPaymentMethodsService.getEnabledMethodsByDriverUserId(ride.driverId);
      if (!accepted.includes(method)) {
        throw new AppError('This driver does not accept the selected payment method', 400, ERROR_CODES.VALIDATION_ERROR);
      }
    }

    return this.repository.updatePaymentMethod(rideId, method);
  }

  /**
   * The method recorded at completion: the passenger's choice when the driver
   * still accepts it, otherwise cash.
   */
  private async resolveCompletedPaymentMethod(
    ride: RideEntity,
    driverUserId: string
  ): Promise<PAYMENT_METHOD> {
    const chosen = ride.paymentMethod;
    if (!chosen || chosen === PAYMENT_METHOD.CASH) return PAYMENT_METHOD.CASH;

    const accepted = await this.driverPaymentMethodsService.getEnabledMethodsByDriverUserId(driverUserId);
    return accepted.includes(chosen) ? chosen : PAYMENT_METHOD.CASH;
  }

  async cancelRide(rideId: string, userId: string, role: USER_ROLE, reason?: string) {
    const ride = await this.repository.findById(rideId);
    if (!ride) throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);

    if (ride.status === RIDE_STATUS.COMPLETED || ride.status === RIDE_STATUS.CANCELLED) {
      throw new AppError('Ride cannot be cancelled in its current state', 400, ERROR_CODES.RIDE_INVALID_STATE);
    }

    // Ownership: customers cancel their own bookings, drivers their assigned rides, admin any
    let cancelledBy: 'customer' | 'driver';
    if (role === USER_ROLE.ADMIN) {
      cancelledBy = ride.customerId === userId ? 'customer' : 'driver';
    } else if (role === USER_ROLE.DRIVER) {
      if (ride.driverId !== userId) {
        throw new AppError('Only the assigned driver can cancel this ride', 403, ERROR_CODES.FORBIDDEN);
      }
      cancelledBy = 'driver';
    } else {
      if (ride.customerId !== userId) {
        throw new AppError('You can only cancel your own rides', 403, ERROR_CODES.FORBIDDEN);
      }
      cancelledBy = 'customer';
    }

    // Free before a driver accepts; once accepted, customer cancellations incur a fee
    // equal to the municipality's base fare
    let cancellationFee = 0;
    if (cancelledBy === 'customer' && ACTIVE_STATUSES.includes(ride.status)) {
      const municipality = await this.municipalitiesService.getMunicipalityById(ride.municipalityId);
      cancellationFee = municipality.baseFare;
    }

    const cancelled = await this.repository.updateStatus(rideId, RIDE_STATUS.CANCELLED, {
      cancellationReason: reason || `Cancelled by ${cancelledBy}`,
      cancelledBy,
      cancellationFee,
    });

    // The party who did not cancel is the one who needs to know.
    await this.notify(() =>
      this.notificationsService.notifyRideCancelled(cancelled ?? ride, cancelledBy)
    );

    return cancelled;
  }

  async getRideTracking(id: string, userId: string, role: USER_ROLE) {
    // Reuses ride access rules (customer owns, assigned driver, admin)
    await this.getRideById(id, userId, role);
    return this.trackingRepository.getRideTrackingHistory(id);
  }

  async rateRide(rideId: string, customerId: string, input: RateRideInput) {
    const ride = await this.requireRatableRide(rideId, customerId);

    const existingRating = await this.repository.findRatingByRideId(rideId);
    if (existingRating) {
      throw new AppError(
        'This ride has already been rated. Edit the existing rating instead.',
        400,
        ERROR_CODES.CONFLICT
      );
    }

    await this.repository.saveRating(rideId, customerId, ride.driverId!, input.rating, input.comment);
    await this.driversRepository.recalculateAverageRating(ride.driverId!);

    return { success: true, message: 'Rating submitted successfully' };
  }

  /**
   * Changes a rating the passenger already gave, within the edit window.
   *
   * Editing exists because a rating is the passenger's own opinion of the trip
   * and is often given in a hurry at the kerb; the window keeps the driver's
   * average from being rewritten long after the fact.
   */
  async updateRideRating(rideId: string, customerId: string, input: RateRideInput) {
    const ride = await this.requireRatableRide(rideId, customerId);

    const existingRating = await this.repository.findRatingByRideId(rideId);
    if (!existingRating) {
      throw new AppError(
        'This ride has not been rated yet',
        404,
        ERROR_CODES.NOT_FOUND
      );
    }

    if (!isWithinRatingEditWindow(ride.completedAt)) {
      throw new AppError(
        `Ratings can only be changed within ${RATING_EDIT_WINDOW_HOURS} hours of the trip`,
        400,
        ERROR_CODES.RIDE_INVALID_STATE
      );
    }

    await this.repository.updateRating(rideId, input.rating, input.comment);
    await this.driversRepository.recalculateAverageRating(ride.driverId!);

    return { success: true, message: 'Rating updated successfully' };
  }

  /** Shared guard for creating or changing a rating. */
  private async requireRatableRide(rideId: string, customerId: string) {
    const ride = await this.repository.findById(rideId);
    if (!ride) throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);
    if (ride.customerId !== customerId) {
      throw new AppError('Only the customer who booked this ride can rate it', 403, ERROR_CODES.FORBIDDEN);
    }
    if (ride.status !== RIDE_STATUS.COMPLETED) {
      throw new AppError('Only completed rides can be rated', 400, ERROR_CODES.RIDE_INVALID_STATE);
    }
    if (!ride.driverId) {
      throw new AppError('Driver not assigned to this ride', 400, ERROR_CODES.BAD_REQUEST);
    }
    return ride;
  }

  private async getAssignedRide(rideId: string, driverUserId: string) {
    const ride = await this.repository.findById(rideId);
    if (!ride) throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);
    if (ride.driverId !== driverUserId) {
      throw new AppError('Only the assigned driver can update this ride', 403, ERROR_CODES.FORBIDDEN);
    }
    return ride;
  }
}
