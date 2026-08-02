import { Request, Response, NextFunction } from 'express';
import { PaymentsService } from './payments.service';

const service = new PaymentsService();

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
      const item = await service.getPaymentByRideId(req.params.rideId);
      return res.status(200).json({ success: true, data: item });
    } catch (error) {
      next(error);
    }
  }
}
