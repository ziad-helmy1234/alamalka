import { extendZodWithOpenApi, OpenAPIRegistry } from '@asteasolutions/zod-to-openapi';
import { z } from 'zod';

extendZodWithOpenApi(z);

export { z };
export const registry = new OpenAPIRegistry();

export const bearerAuth = registry.registerComponent('securitySchemes', 'bearerAuth', {
  type: 'http',
  scheme: 'bearer',
  bearerFormat: 'JWT',
});

export const ErrorResponse = registry.register(
  'Error',
  z.object({
    error: z.object({
      code: z.string().openapi({ example: 'VALIDATION_ERROR' }),
      message: z.string(),
      details: z.any().optional(),
    }),
  }),
);

const err = (description: string) => ({ description, content: { 'application/json': { schema: ErrorResponse } } });
export const commonErrors = {
  400: err('Validation error'),
  401: err('Missing / invalid / expired access token'),
  429: err('Rate limited'),
};

export const secured = [{ [bearerAuth.name]: [] }];

/** Decimal amounts are accepted as numbers or numeric strings and returned as strings (no float drift). */
export const money = z
  .union([z.number(), z.string().regex(/^\d+(\.\d{1,4})?$/)])
  .transform((v) => String(v))
  .refine((v) => Number(v) > 0, 'Must be greater than 0')
  .openapi({ type: 'string', example: '1500.50', description: 'Positive decimal, up to 4 dp' });

export const CurrencyEnum = z.enum(['EGP', 'USD']).openapi('Currency');
