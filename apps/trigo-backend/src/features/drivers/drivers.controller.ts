import { Request, Response, NextFunction } from 'express';
import { DriversService } from './drivers.service';
import { DRIVER_APPLICATION_STATUS } from '../../shared/constants/roles';

const service = new DriversService();

export class DriversController {
  async apply(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.apply(req.user!.id, req.body);
      return res.status(201).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async getOwnProfile(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.getOwnProfile(req.user!.id);
      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async getAllDrivers(req: Request, res: Response, next: NextFunction) {
    try {
      const drivers = await service.getAllDrivers();
      return res.status(200).json({ success: true, data: drivers });
    } catch (error) {
      next(error);
    }
  }

  async getOnlineDrivers(req: Request, res: Response, next: NextFunction) {
    try {
      const drivers = await service.getOnlineDrivers();
      return res.status(200).json({ success: true, data: drivers });
    } catch (error) {
      next(error);
    }
  }

  async getDriverById(req: Request, res: Response, next: NextFunction) {
    try {
      const driver = await service.getDriverById(req.params.id);
      return res.status(200).json({ success: true, data: driver });
    } catch (error) {
      next(error);
    }
  }

  async getApplications(req: Request, res: Response, next: NextFunction) {
    try {
      const status = req.query.status as DRIVER_APPLICATION_STATUS | undefined;
      const apps = await service.getApplications(status);
      return res.status(200).json({ success: true, data: apps });
    } catch (error) {
      next(error);
    }
  }

  async getApplicationById(req: Request, res: Response, next: NextFunction) {
    try {
      const app = await service.getApplicationById(req.params.id);
      return res.status(200).json({ success: true, data: app });
    } catch (error) {
      next(error);
    }
  }

  async startReview(req: Request, res: Response, next: NextFunction) {
    try {
      const reviewing = await service.startReview(req.params.id);
      return res.status(200).json({ success: true, data: reviewing });
    } catch (error) {
      next(error);
    }
  }

  async approveApplication(req: Request, res: Response, next: NextFunction) {
    try {
      const approved = await service.approveApplication(req.params.id);
      return res.status(200).json({ success: true, data: approved });
    } catch (error) {
      next(error);
    }
  }

  async rejectApplication(req: Request, res: Response, next: NextFunction) {
    try {
      const rejected = await service.rejectApplication(req.params.id, req.body.reason);
      return res.status(200).json({ success: true, data: rejected });
    } catch (error) {
      next(error);
    }
  }

  async updateDriverStatus(req: Request, res: Response, next: NextFunction) {
    try {
      const updated = await service.updateDriverStatus(req.params.id, req.body.status);
      return res.status(200).json({ success: true, data: updated });
    } catch (error) {
      next(error);
    }
  }

  async toggleOnlineStatus(req: Request, res: Response, next: NextFunction) {
    try {
      const updated = await service.toggleOnlineStatus(req.user!.id, req.body.isOnline);
      return res.status(200).json({ success: true, data: updated });
    } catch (error) {
      next(error);
    }
  }
}
