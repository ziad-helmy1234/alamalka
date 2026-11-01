import type { NextFunction, Request, Response } from 'express';
import type { ZodTypeAny } from 'zod';
import { BadRequest } from '../lib/errors';

interface Schemas {
  body?: ZodTypeAny;
  query?: ZodTypeAny;
  params?: ZodTypeAny;
}

/**
 * Validates and coerces request input. Parsed values are written to req.valid
 * (Express 5 makes req.query read-only, and handlers should only ever use validated data).
 */
export function validate(schemas: Schemas) {
  return (req: Request, _res: Response, next: NextFunction) => {
    req.valid ??= {};
    for (const key of ['params', 'query', 'body'] as const) {
      const schema = schemas[key];
      if (!schema) continue;
      const result = schema.safeParse(req[key] ?? {});
      if (!result.success) {
        throw BadRequest('VALIDATION_ERROR', `Invalid request ${key}`, result.error.issues.map((i) => ({
          path: i.path.join('.'),
          message: i.message,
        })));
      }
      req.valid[key] = result.data;
    }
    next();
  };
}
