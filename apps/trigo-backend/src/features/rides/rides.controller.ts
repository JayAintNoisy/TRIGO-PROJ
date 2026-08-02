import { Request, Response, NextFunction } from 'express';
import { RidesService } from './rides.service';
import { RIDE_STATUS } from '../../shared/constants/ride-status';

const service = new RidesService();

export class RidesController {
  async requestRide(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.requestRide(req.user!.id, req.body);
      return res.status(201).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async listRides(req: Request, res: Response, next: NextFunction) {
    try {
      const statusFilter = req.query.status as RIDE_STATUS | undefined;
      const list = await service.listRides({ id: req.user!.id, role: req.user!.role }, statusFilter);
      return res.status(200).json({ success: true, data: list });
    } catch (error) {
      next(error);
    }
  }

  async getRideById(req: Request, res: Response, next: NextFunction) {
    try {
      const ride = await service.getRideById(req.params.id, req.user!.id, req.user!.role);
      return res.status(200).json({ success: true, data: ride });
    } catch (error) {
      next(error);
    }
  }

  async acceptRide(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.acceptRide(req.params.id, req.user!.id);
      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async arrive(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.markArrived(req.params.id, req.user!.id);
      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async startRide(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.startRide(req.params.id, req.user!.id);
      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async completeRide(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.completeRide(req.params.id, req.user!.id);
      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async cancelRide(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.cancelRide(req.params.id, req.user!.id, req.user!.role, req.body.reason);
      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async rateRide(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.rateRide(req.params.id, req.user!.id, req.body);
      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }
}
