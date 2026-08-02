import { Request, Response, NextFunction } from 'express';
import { AppError } from '../errors/app-error';
import { ERROR_CODES } from '../errors/error-codes';
import { USER_ROLE } from '../constants/roles';

export const authorize = (...allowedRoles: USER_ROLE[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return next(new AppError('Unauthorized access', 401, ERROR_CODES.UNAUTHORIZED));
    }

    if (!allowedRoles.includes(req.user.role)) {
      return next(new AppError('Forbidden: Insufficient privileges', 403, ERROR_CODES.FORBIDDEN));
    }

    next();
  };
};
