import type { NextFunction, Request, Response } from 'express';
import { redis } from '../lib/redis';
import { AppError } from '../lib/errors';
import { logger } from '../lib/logger';

interface Options {
  /** Bucket name, e.g. "auth". */
  name: string;
  limit: number;
  windowSec?: number;
  /** Defaults to client IP; authenticated routes can key by user id. */
  key?: (req: Request) => string;
}

/**
 * Fixed-window rate limiter backed by Redis, so limits hold across all API instances.
 * Fails open if Redis is unavailable (availability over strictness; logged).
 */
export function rateLimit({ name, limit, windowSec = 60, key }: Options) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const id = key?.(req) ?? req.ip ?? 'unknown';
    const window = Math.floor(Date.now() / 1000 / windowSec);
    const redisKey = `rl:${name}:${id}:${window}`;
    let count: number;
    try {
      const results = await redis.multi().incr(redisKey).expire(redisKey, windowSec + 1).exec();
      count = Number(results?.[0]?.[1] ?? 0);
    } catch (err) {
      logger.warn({ err: (err as Error).message }, 'rate limiter unavailable');
      return next();
    }
    const resetIn = windowSec - (Math.floor(Date.now() / 1000) % windowSec);
    res.setHeader('RateLimit-Limit', String(limit));
    res.setHeader('RateLimit-Remaining', String(Math.max(0, limit - count)));
    res.setHeader('RateLimit-Reset', String(resetIn));
    if (count > limit) {
      res.setHeader('Retry-After', String(resetIn));
      throw new AppError(429, 'RATE_LIMITED', 'Too many requests, please slow down');
    }
    next();
  };
}
