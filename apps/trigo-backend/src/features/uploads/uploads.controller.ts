import { Request, Response, NextFunction } from 'express';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';
import { readUpload, saveUpload } from './uploads.service';

export class UploadsController {
  async uploadDocument(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const file = req.file;
      if (!file) {
        throw new AppError(
          'No file provided. Send multipart/form-data with a "file" field',
          400,
          ERROR_CODES.VALIDATION_ERROR,
        );
      }
      const folder = (req.body?.folder ?? 'driver-documents') as string;
      const stored = await saveUpload(folder, file.mimetype, file.buffer);
      res.status(201).json({ success: true, data: stored });
    } catch (error) {
      next(error);
    }
  }

  async fetchDocument(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const { absolutePath, mimeType } = await readUpload(
        req.params.folder,
        req.params.filename,
      );
      res.setHeader('Content-Type', mimeType);
      res.setHeader('Cache-Control', 'private, max-age=3600');
      res.sendFile(absolutePath, (error) => {
        // Headers already sent means the stream started; defer to Express
        if (error && !res.headersSent) {
          next(new AppError('File not found', 404, ERROR_CODES.NOT_FOUND));
        }
      });
    } catch (error) {
      next(error);
    }
  }
}
