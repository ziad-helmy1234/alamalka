import type { NextFunction, Request, Response } from 'express';
import type { Role } from '@prisma/client';
import { Forbidden, Unauthorized } from '../lib/errors';
import { isAccessTokenRevoked, verifyAccessToken } from '../lib/tokens';

export async function requireAuth(req: Request, _res: Response, next: NextFunction): Promise<void> {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) throw Unauthorized();
  const token = header.slice(7).trim();

  let claims;
  try {
    claims = verifyAccessToken(token);
  } catch (err) {
    const expired = (err as Error).name === 'TokenExpiredError';
    throw Unauthorized(expired ? 'Access token expired' : 'Invalid access token', expired ? 'TOKEN_EXPIRED' : 'INVALID_TOKEN');
  }
  if (await isAccessTokenRevoked(claims.sub, claims.pv)) {
    throw Unauthorized('Session revoked, please sign in again', 'TOKEN_REVOKED');
  }
  req.user = { id: claims.sub, role: claims.role, unifiedId: claims.uid };
  next();
}

export function requireRole(...roles: Role[]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.user) throw Unauthorized();
    if (!roles.includes(req.user.role)) throw Forbidden();
    next();
  };
}
