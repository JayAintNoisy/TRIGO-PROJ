import { PaymentsRepository } from './payments.repository';
import { RidesRepository } from '../rides/rides.repository';
import { USER_ROLE } from '../../shared/constants/roles';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';

export class PaymentsService {
  private repository = new PaymentsRepository();
  private ridesRepository = new RidesRepository();

  async getAllPayments() {
    return this.repository.findAll();
  }

  async getPaymentById(id: string) {
    const payment = await this.repository.findById(id);
    if (!payment) throw new AppError('Payment record not found', 404, ERROR_CODES.NOT_FOUND);
    return payment;
  }

  /**
   * The payment recorded for a ride, readable by the two people on it (and an
   * admin). Without this check any signed-in user could read any ride's
   * payment by guessing its id.
   */
  async getPaymentByRideId(rideId: string, userId: string, role: USER_ROLE) {
    const ride = await this.ridesRepository.findById(rideId);
    if (!ride) throw new AppError('Ride not found', 404, ERROR_CODES.NOT_FOUND);

    if (role !== USER_ROLE.ADMIN && ride.customerId !== userId && ride.driverId !== userId) {
      throw new AppError('Access denied to this ride payment', 403, ERROR_CODES.FORBIDDEN);
    }

    const payment = await this.repository.findByRideId(rideId);
    if (!payment) throw new AppError('Payment record for this ride not found', 404, ERROR_CODES.NOT_FOUND);
    return payment;
  }
}
