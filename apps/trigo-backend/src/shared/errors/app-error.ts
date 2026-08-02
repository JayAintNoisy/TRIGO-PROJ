import { ERROR_CODES } from './error-codes';

export class AppError extends Error {
  public readonly statusCode: number;
  public readonly errorCode: ERROR_CODES;
  public readonly details?: any;

  constructor(message: string, statusCode: number = 500, errorCode: ERROR_CODES = ERROR_CODES.INTERNAL_ERROR, details?: any) {
    super(message);
    this.statusCode = statusCode;
    this.errorCode = errorCode;
    this.details = details;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}
