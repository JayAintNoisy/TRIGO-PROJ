import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../../env';
import { AppError } from '../errors/app-error';
import { ERROR_CODES } from '../errors/error-codes';
import { USER_ROLE } from '../constants/roles';

export interface AuthUserPayload {
  id: string;
  email: string;
  role: USER_ROLE;
  name: string;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthUserPayload;
    }
  }
}

export const authenticate = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(new AppError('No authorization token provided', 401, ERROR_CODES.UNAUTHORIZED));
  }

  const token = authHeader.split(' ')[1];
  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as AuthUserPayload;
    req.user = payload;
    next();
  } catch (err) {
    return next(new AppError('Invalid or expired authentication token', 401, ERROR_CODES.UNAUTHORIZED));
  }
};
