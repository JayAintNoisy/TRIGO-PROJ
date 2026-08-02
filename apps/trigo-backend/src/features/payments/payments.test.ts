import { describe, it, expect, vi } from 'vitest';
import { PaymentsService } from './payments.service';
import { PaymentsRepository } from './payments.repository';
import { PAYMENT_METHOD, PAYMENT_STATUS } from '../../shared/constants/payment-status';

describe('PaymentsService', () => {
  const service = new PaymentsService();
  const mockPayment = {
    id: 'pay-uuid-001',
    rideId: 'ride-uuid-001',
    amount: 45.0,
    method: PAYMENT_METHOD.CASH,
    status: PAYMENT_STATUS.COMPLETED,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  it('fetches all payments', async () => {
    vi.spyOn(PaymentsRepository.prototype, 'findAll').mockResolvedValue([mockPayment]);
    const list = await service.getAllPayments();
    expect(list.length).toBeGreaterThan(0);
  });
});
