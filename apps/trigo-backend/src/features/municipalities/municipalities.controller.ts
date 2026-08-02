import { Request, Response, NextFunction } from 'express';
import { MunicipalitiesService } from './municipalities.service';

const service = new MunicipalitiesService();

export class MunicipalitiesController {
  async getAll(req: Request, res: Response, next: NextFunction) {
    try {
      const list = await service.getAllMunicipalities();
      return res.status(200).json({ success: true, data: list });
    } catch (error) {
      next(error);
    }
  }

  async getById(req: Request, res: Response, next: NextFunction) {
    try {
      const item = await service.getMunicipalityById(req.params.id);
      return res.status(200).json({ success: true, data: item });
    } catch (error) {
      next(error);
    }
  }

  async create(req: Request, res: Response, next: NextFunction) {
    try {
      const created = await service.createMunicipality(req.body);
      return res.status(201).json({ success: true, data: created });
    } catch (error) {
      next(error);
    }
  }

  async updateFareConfig(req: Request, res: Response, next: NextFunction) {
    try {
      const updated = await service.updateFareConfig(req.params.id, req.body);
      return res.status(200).json({ success: true, data: updated });
    } catch (error) {
      next(error);
    }
  }
}
