import { Request, Response, NextFunction } from 'express';
import { MessagingService } from './messaging.service';

const service = new MessagingService();

export class MessagingController {
  async listMessages(req: Request, res: Response, next: NextFunction) {
    try {
      const messages = await service.listMessages(req.params.id, req.user!.id);
      return res.status(200).json({ success: true, data: messages });
    } catch (error) {
      next(error);
    }
  }

  async sendMessage(req: Request, res: Response, next: NextFunction) {
    try {
      const message = await service.sendMessage(req.params.id, req.user!.id, req.body.body);
      return res.status(201).json({ success: true, data: message });
    } catch (error) {
      next(error);
    }
  }

  async markRead(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await service.markRead(req.params.id, req.user!.id);
      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }
}
