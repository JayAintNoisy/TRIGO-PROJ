import { Request, Response, NextFunction } from 'express';
import { AnyZodObject, ZodError } from 'zod';
import { AppError } from '../errors/app-error';
import { ERROR_CODES } from '../errors/error-codes';

export const validate = (schema: AnyZodObject) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      await schema.parseAsync({
        body: req.body,
        query: req.query,
        params: req.params,
      });
      return next();
    } catch (error) {
      if (error instanceof ZodError) {
        return next(
          new AppError(
            'Validation failed',
            400,
            ERROR_CODES.VALIDATION_ERROR,
            error.errors
          )
        );
      }
      return next(error);
    }
  };
};
