import { PAYMENT_METHOD, PAYMENT_STATUS } from '../../shared/constants/payment-status';

export interface PaymentEntity {
  id: string;
  rideId: string;
  amount: number;
  method: PAYMENT_METHOD;
  status: PAYMENT_STATUS;
  createdAt: Date;
  updatedAt: Date;
}
