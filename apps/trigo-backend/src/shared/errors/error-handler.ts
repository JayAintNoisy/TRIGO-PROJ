import { Request, Response, NextFunction } from 'express';
import { AppError } from './app-error';
import { ERROR_CODES } from './error-codes';
import { logger } from '../logging/logger';

export const errorHandler = (
  err: Error,
  req: Request,
  res: Response,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  next: NextFunction
) => {
  if (err instanceof AppError) {
    logger.warn(`AppError [${err.errorCode}]: ${err.message}`, { details: err.details });
    return res.status(err.statusCode).json({
      success: false,
      error: {
        code: err.errorCode,
        message: err.message,
        details: err.details
      }
    });
  }

  logger.error('Unhandled internal server error:', err);
  return res.status(500).json({
    success: false,
    error: {
      code: ERROR_CODES.INTERNAL_ERROR,
      message: 'Internal server error'
    }
  });
};
