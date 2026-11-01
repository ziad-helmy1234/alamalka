export class AppError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export const BadRequest = (code: string, msg: string, details?: unknown) => new AppError(400, code, msg, details);
export const Unauthorized = (msg = 'Authentication required', code = 'UNAUTHORIZED') => new AppError(401, code, msg);
export const Forbidden = (msg = 'Forbidden') => new AppError(403, 'FORBIDDEN', msg);
export const NotFound = (what = 'Resource') => new AppError(404, 'NOT_FOUND', `${what} not found`);
export const Conflict = (code: string, msg: string) => new AppError(409, code, msg);
export const Unprocessable = (code: string, msg: string, details?: unknown) => new AppError(422, code, msg, details);
