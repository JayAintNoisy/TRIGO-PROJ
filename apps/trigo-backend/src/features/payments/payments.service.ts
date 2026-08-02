import { PaymentsRepository } from './payments.repository';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';

export class PaymentsService {
  private repository = new PaymentsRepository();

  async getAllPayments() {
    return this.repository.findAll();
  }

  async getPaymentById(id: string) {
    const payment = await this.repository.findById(id);
    if (!payment) throw new AppError('Payment record not found', 404, ERROR_CODES.NOT_FOUND);
    return payment;
  }

  async getPaymentByRideId(rideId: string) {
    const payment = await this.repository.findByRideId(rideId);
    if (!payment) throw new AppError('Payment record for this ride not found', 404, ERROR_CODES.NOT_FOUND);
    return payment;
  }
}
