import { Request, Response, NextFunction } from 'express';
import { NotificationsService } from './notifications.service';

const service = new NotificationsService();

export class NotificationsController {
  async getNotifications(req: Request, res: Response, next: NextFunction) {
    try {
      const list = await service.getUserNotifications(req.user!.id);
      return res.status(200).json({ success: true, data: list });
    } catch (error) {
      next(error);
    }
  }

  async markAsRead(req: Request, res: Response, next: NextFunction) {
    try {
      await service.markAsRead(req.params.id, req.user!.id);
      return res.status(200).json({ success: true, message: 'Notification marked as read' });
    } catch (error) {
      next(error);
    }
  }

  async registerDevice(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.registerDevice(req.user!.id, req.body);
      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async broadcast(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.broadcast(req.body.title, req.body.body, req.body.audience);
      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }
}
