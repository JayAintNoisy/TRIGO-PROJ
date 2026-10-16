import { Request, Response, NextFunction } from 'express';
import { TrackingService } from './tracking.service';

const service = new TrackingService();

export class TrackingController {
  async recordLocation(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.recordLocation(req.user!.id, req.body);
      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async getActiveDrivers(req: Request, res: Response, next: NextFunction) {
    try {
      const municipalityId = req.query.municipalityId as string | undefined;
      const drivers = await service.getActiveDrivers(municipalityId);
      return res.status(200).json({ success: true, data: drivers });
    } catch (error) {
      next(error);
    }
  }
}
