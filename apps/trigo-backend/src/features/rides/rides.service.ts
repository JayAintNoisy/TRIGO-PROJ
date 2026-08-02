import { RidesRepository } from './rides.repository';
import { MunicipalitiesService } from '../municipalities/municipalities.service';
import { DriversRepository } from '../drivers/drivers.repository';
import { CreateRideInput, RateRideInput } from './rides.types';
import { calculateFare } from '../../shared/utils/calculate-fare';
import { RIDE_STATUS } from '../../shared/constants/ride-status';
import { USER_ROLE } from '../../shared/constants/roles';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';

export class RidesService {
  private repository = new RidesRepository();
  private municipalitiesService = new MunicipalitiesService();
  private driversRepository = new DriversRepository();

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

    // 3. Calculate distance & fare estimate
    const fareResult = calculateFare({
      pickupLat: input.pickupLat,
      pickupLng: input.pickupLng,
      dropoffLat: input.dropoffLat,
      dropoffLng: input.dropoffLng,
      baseFare: municipality.baseFare,
      perKmRate: municipality.perKmRate,
    });

    // 4. Create ride entity
    return this.repository.create({
      customerId,
      municipalityId: input.municipalityId,
      pickupLat: input.pickupLat,
      pickupLng: input.pickupLng,
      pickupAddress: input.pickupAddress || 'Selected Pickup Location',
      dropoffLat: input.dropoffLat,
      dropoffLng: input.dropoffLng,
      dropoffAddress: input.dropoffAddress || 'Selected Destination',
      status: RIDE_STATUS.REQUESTED,
      fareEstimate: fareResult.totalFare,
      distanceKm: fareResult.distanceKm,
    });
  }

  async listRides(user: { id: string; role: USER_ROLE }, filterStatus?: RIDE_STATUS) {
    if (user.role === USER_ROLE.ADMIN) {
      return this.repository.findAll({ status: filterStatus });
    }
    if (user.role === USER_ROLE.DRIVER) {
      const driverProf = await this.driversRepository.findByUserId(user.id);
      return this.repository.findAll({ driverId: driverProf?.id || user.id, status: filterStatus });
    }
    return this.repository.findAll({ customerId: user.id, status: filterStatus });
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
    const ride = await this.repository.findById(rideId);
    if (!ride) throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);
    if (ride.driverId !== driverUserId && ride.driverId !== 'driver-prof-001') {
      throw new AppError('Only the assigned driver can update this ride', 403, ERROR_CODES.FORBIDDEN);
    }
    if (ride.status !== RIDE_STATUS.ACCEPTED) {
      throw new AppError('Invalid ride status for driver arrival', 400, ERROR_CODES.RIDE_INVALID_STATE);
    }

    return this.repository.updateStatus(rideId, RIDE_STATUS.DRIVER_ARRIVING);
  }

  async startRide(rideId: string, driverUserId: string) {
    const ride = await this.repository.findById(rideId);
    if (!ride) throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);
    if (ride.driverId !== driverUserId && ride.driverId !== 'driver-prof-001') {
      throw new AppError('Only the assigned driver can update this ride', 403, ERROR_CODES.FORBIDDEN);
    }

    return this.repository.updateStatus(rideId, RIDE_STATUS.IN_PROGRESS, { startedAt: new Date() });
  }

  async completeRide(rideId: string, driverUserId: string) {
    const ride = await this.repository.findById(rideId);
    if (!ride) throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);
    if (ride.driverId !== driverUserId && ride.driverId !== 'driver-prof-001') {
      throw new AppError('Only the assigned driver can update this ride', 403, ERROR_CODES.FORBIDDEN);
    }

    return this.repository.updateStatus(rideId, RIDE_STATUS.COMPLETED, {
      fareFinal: ride.fareEstimate,
      completedAt: new Date(),
    });
  }

  async cancelRide(rideId: string, userId: string, role: USER_ROLE, reason?: string) {
    const ride = await this.repository.findById(rideId);
    if (!ride) throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);

    if (ride.status === RIDE_STATUS.COMPLETED || ride.status === RIDE_STATUS.CANCELLED) {
      throw new AppError('Ride cannot be cancelled in its current state', 400, ERROR_CODES.RIDE_INVALID_STATE);
    }

    const cancelledBy = role === USER_ROLE.DRIVER ? 'driver' : 'customer';
    return this.repository.updateStatus(rideId, RIDE_STATUS.CANCELLED, {
      cancellationReason: reason || 'Cancelled by user',
      cancelledBy,
    });
  }

  async rateRide(rideId: string, customerId: string, input: RateRideInput) {
    const ride = await this.repository.findById(rideId);
    if (!ride) throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);
    if (ride.customerId !== customerId) {
      throw new AppError('Only the customer who booked this ride can submit a rating', 403, ERROR_CODES.FORBIDDEN);
    }
    if (ride.status !== RIDE_STATUS.COMPLETED) {
      throw new AppError('Only completed rides can be rated', 400, ERROR_CODES.RIDE_INVALID_STATE);
    }
    if (!ride.driverId) {
      throw new AppError('Driver not assigned to this ride', 400, ERROR_CODES.BAD_REQUEST);
    }

    await this.repository.saveRating(rideId, customerId, ride.driverId, input.rating, input.comment);
    return { success: true, message: 'Rating submitted successfully' };
  }
}
