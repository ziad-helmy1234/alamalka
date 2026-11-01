import type { NextFunction, Request, Response } from 'express';
import { Prisma } from '@prisma/client';
import { AppError } from '../lib/errors';
import { logger } from '../lib/logger';
import { isProd } from '../config/env';

export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({ error: { code: 'NOT_FOUND', message: `Route ${req.method} ${req.path} not found` } });
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorHandler(err: unknown, req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof AppError) {
    res.status(err.status).json({ error: { code: err.code, message: err.message, details: err.details } });
    return;
  }

  // Malformed JSON body
  if ((err as { type?: string }).type === 'entity.parse.failed') {
    res.status(400).json({ error: { code: 'INVALID_JSON', message: 'Malformed JSON body' } });
    return;
  }
  if ((err as { type?: string }).type === 'entity.too.large') {
    res.status(413).json({ error: { code: 'PAYLOAD_TOO_LARGE', message: 'Request body too large' } });
    return;
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === 'P2002') {
      res.status(409).json({ error: { code: 'CONFLICT', message: 'Resource already exists' } });
      return;
    }
    if (err.code === 'P2028' || err.code === 'P2024') {
      // Could not get a DB connection / start a transaction in time: transient overload, safe to retry.
      res.setHeader('Retry-After', '1');
      res.status(503).json({ error: { code: 'SERVICE_BUSY', message: 'Service is busy, please retry' } });
      return;
    }
    if (err.code === 'P2025') {
      res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Resource not found' } });
      return;
    }
  }

  // A CHECK constraint fired — the DB refused to break a financial invariant.
  const msg = String((err as Error)?.message ?? '');
  if (msg.includes('violates check constraint')) {
    logger.warn({ err: msg, path: req.path }, 'check constraint rejected write');
    res.status(409).json({ error: { code: 'INVARIANT_VIOLATION', message: 'Operation would violate account limits' } });
    return;
  }

  logger.error({ err, path: req.path, reqId: req.id }, 'unhandled error');
  res.status(500).json({
    error: { code: 'INTERNAL_ERROR', message: isProd ? 'Internal server error' : msg || 'Internal server error' },
  });
}
