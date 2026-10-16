import { describe, it, expect, vi, beforeEach } from 'vitest';
import { PaymentsService } from './payments.service';
import { PaymentsRepository } from './payments.repository';
import { RidesRepository } from '../rides/rides.repository';
import { PAYMENT_METHOD, PAYMENT_STATUS } from '../../shared/constants/payment-status';
import { USER_ROLE } from '../../shared/constants/roles';

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

  const mockRide = (overrides: Record<string, unknown> = {}) =>
    ({
      id: 'ride-uuid-001',
      customerId: 'customer-1',
      driverId: 'driver-1',
      status: 'completed',
      ...overrides,
    }) as any;

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('fetches all payments', async () => {
    vi.spyOn(PaymentsRepository.prototype, 'findAll').mockResolvedValue([mockPayment]);
    const list = await service.getAllPayments();
    expect(list.length).toBeGreaterThan(0);
  });

  it('lets the passenger on the ride read its payment', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide());
    vi.spyOn(PaymentsRepository.prototype, 'findByRideId').mockResolvedValue(mockPayment);

    await expect(
      service.getPaymentByRideId('ride-uuid-001', 'customer-1', USER_ROLE.CUSTOMER)
    ).resolves.toEqual(mockPayment);
  });

  it('lets the assigned driver read its payment', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide());
    vi.spyOn(PaymentsRepository.prototype, 'findByRideId').mockResolvedValue(mockPayment);

    await expect(
      service.getPaymentByRideId('ride-uuid-001', 'driver-1', USER_ROLE.DRIVER)
    ).resolves.toEqual(mockPayment);
  });

  it('refuses a signed-in stranger', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide());
    const paymentSpy = vi.spyOn(PaymentsRepository.prototype, 'findByRideId');

    await expect(
      service.getPaymentByRideId('ride-uuid-001', 'someone-else', USER_ROLE.CUSTOMER)
    ).rejects.toMatchObject({ statusCode: 403 });
    expect(paymentSpy).not.toHaveBeenCalled();
  });

  it('404s for an unknown ride', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(null);

    await expect(
      service.getPaymentByRideId('missing', 'customer-1', USER_ROLE.CUSTOMER)
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it('reports a missing payment record for a readable ride', async () => {
    vi.spyOn(RidesRepository.prototype, 'findById').mockResolvedValue(mockRide());
    vi.spyOn(PaymentsRepository.prototype, 'findByRideId').mockResolvedValue(null);

    await expect(
      service.getPaymentByRideId('ride-uuid-001', 'customer-1', USER_ROLE.CUSTOMER)
    ).rejects.toThrow('Payment record for this ride not found');
  });
});
