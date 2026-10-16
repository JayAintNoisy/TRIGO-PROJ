import { Request, Response, NextFunction } from 'express';
import { PaymentsService } from './payments.service';
import { DriverPaymentMethodsService } from './driver-payment-methods.service';
import { PAYMENT_METHOD } from '../../shared/constants/payment-status';

const service = new PaymentsService();
const driverMethodsService = new DriverPaymentMethodsService();

export class PaymentsController {
  async getAll(req: Request, res: Response, next: NextFunction) {
    try {
      const list = await service.getAllPayments();
      return res.status(200).json({ success: true, data: list });
    } catch (error) {
      next(error);
    }
  }

  async getById(req: Request, res: Response, next: NextFunction) {
    try {
      const item = await service.getPaymentById(req.params.id);
      return res.status(200).json({ success: true, data: item });
    } catch (error) {
      next(error);
    }
  }

  async getByRideId(req: Request, res: Response, next: NextFunction) {
    try {
      const item = await service.getPaymentByRideId(
        req.params.rideId,
        req.user!.id,
        req.user!.role,
      );
      return res.status(200).json({ success: true, data: item });
    } catch (error) {
      next(error);
    }
  }

  /** The driver's own payment methods, including the always-on cash default. */
  async getOwnPaymentMethods(req: Request, res: Response, next: NextFunction) {
    try {
      const list = await driverMethodsService.getOwnPaymentMethods(req.user!.id);
      return res.status(200).json({ success: true, data: list });
    } catch (error) {
      next(error);
    }
  }

  /** Enables or disables one of the driver's payment methods. */
  async updateOwnPaymentMethod(req: Request, res: Response, next: NextFunction) {
    try {
      const method = req.params.method as PAYMENT_METHOD;
      const updated = await driverMethodsService.updateOwnPaymentMethod(req.user!.id, method, {
        isEnabled: req.body.isEnabled,
        qrCodeUrl: req.body.qrCodeUrl,
      });
      return res.status(200).json({ success: true, data: updated });
    } catch (error) {
      next(error);
    }
  }
}
