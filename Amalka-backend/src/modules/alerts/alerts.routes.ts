import { Router } from 'express';
import { Prisma, type PriceAlert } from '@prisma/client';
import { commonErrors, ErrorResponse, registry, secured, z } from '../../docs/registry';
import { NotFound, Unprocessable } from '../../lib/errors';
import { prisma } from '../../lib/prisma';
import { requireAuth } from '../../middleware/auth';
import { validate } from '../../middleware/validate';
import { publishToUser, type TickPayload } from '../../realtime/events';

const MAX_ACTIVE_ALERTS = 50;

export const alertsRouter = Router();
alertsRouter.use(requireAuth);

const CreateBody = z
  .object({
    symbol: z.string().trim().toUpperCase().min(1).max(16).openapi({ example: 'TMGH' }),
    targetPrice: z
      .union([z.number(), z.string()])
      .transform(String)
      .refine((v) => /^\d+(\.\d{1,4})?$/.test(v) && Number(v) > 0, 'targetPrice must be a positive number')
      .openapi({ type: 'string', example: '60.00' }),
    condition: z.enum(['RISES_ABOVE', 'FALLS_BELOW']).openapi('AlertCondition'),
  })
  .strict()
  .openapi('CreatePriceAlertRequest');
const ListQuery = z.object({ includeTriggered: z.enum(['true', 'false']).transform((v) => v === 'true').default('false') });
const IdParams = z.object({ id: z.string().uuid() });

const dto = (a: PriceAlert) => ({
  id: a.id,
  symbol: a.symbol,
  targetPrice: a.targetPrice.toFixed(4),
  condition: a.condition,
  isTriggered: a.isTriggered,
  triggeredAt: a.triggeredAt?.toISOString() ?? null,
  createdAt: a.createdAt.toISOString(),
});

alertsRouter.post('/', validate({ body: CreateBody }), async (req, res) => {
  const { symbol, targetPrice, condition } = req.valid.body;
  const stock = await prisma.stock.findUnique({ where: { symbol } });
  if (!stock || !stock.isActive) throw NotFound(`Stock ${symbol}`);
  const active = await prisma.priceAlert.count({ where: { userId: req.user!.id, isTriggered: false } });
  if (active >= MAX_ACTIVE_ALERTS) throw Unprocessable('ALERT_LIMIT', `You can have at most ${MAX_ACTIVE_ALERTS} active alerts`);
  const alert = await prisma.priceAlert.create({ data: { userId: req.user!.id, symbol, targetPrice, condition } });
  res.status(201).json(dto(alert));
});

alertsRouter.get('/', validate({ query: ListQuery }), async (req, res) => {
  const alerts = await prisma.priceAlert.findMany({
    where: { userId: req.user!.id, ...(req.valid.query.includeTriggered ? {} : { isTriggered: false }) },
    orderBy: { createdAt: 'desc' },
  });
  res.json(alerts.map(dto));
});

alertsRouter.delete('/:id', validate({ params: IdParams }), async (req, res) => {
  const { count } = await prisma.priceAlert.deleteMany({ where: { id: req.valid.params.id, userId: req.user!.id } });
  if (count === 0) throw NotFound('Price alert');
  res.status(204).end();
});

/**
 * Trigger alerts for a batch of ticks in ONE atomic statement. The conditional
 * UPDATE … WHERE is_triggered = false … RETURNING guarantees each alert fires
 * exactly once, even with several instances evaluating concurrently.
 */
export async function evaluateAlerts(ticks: TickPayload[]): Promise<number> {
  if (ticks.length === 0) return 0;
  const values = Prisma.join(ticks.map((t) => Prisma.sql`(${t.symbol}::varchar, ${t.price}::numeric)`));
  const fired = await prisma.$queryRaw<
    { id: string; user_id: string; symbol: string; target_price: Prisma.Decimal; condition: string; price: Prisma.Decimal }[]
  >`
    UPDATE "price_alerts" AS a
       SET "is_triggered" = true, "triggered_at" = now()
      FROM (VALUES ${values}) AS p(symbol, price)
     WHERE a."symbol" = p.symbol
       AND a."is_triggered" = false
       AND ((a."condition" = 'RISES_ABOVE' AND p.price >= a."target_price")
         OR (a."condition" = 'FALLS_BELOW' AND p.price <= a."target_price"))
    RETURNING a."id"::text AS id, a."user_id"::text AS user_id, a."symbol", a."target_price", a."condition"::text AS condition, p.price`;

  for (const a of fired) {
    await publishToUser(a.user_id, {
      type: 'price_alert',
      data: {
        id: a.id,
        symbol: a.symbol,
        condition: a.condition,
        targetPrice: String(a.target_price),
        price: String(a.price),
        triggeredAt: new Date().toISOString(),
      },
    });
  }
  return fired.length;
}

// ---- OpenAPI ----
const Alert = z
  .object({
    id: z.string().uuid(), symbol: z.string(), targetPrice: z.string(), condition: z.enum(['RISES_ABOVE', 'FALLS_BELOW']),
    isTriggered: z.boolean(), triggeredAt: z.string().nullable(), createdAt: z.string(),
  })
  .openapi('PriceAlert');
const json = <T extends z.ZodTypeAny>(schema: T) => ({ content: { 'application/json': { schema } } });

registry.registerPath({
  method: 'post', path: '/api/v1/price-alerts', tags: ['Price Alerts'], security: secured, summary: 'Create a price alert',
  request: { body: json(CreateBody) },
  responses: { 201: { description: 'Created', ...json(Alert) }, 404: { description: 'Unknown symbol', ...json(ErrorResponse) }, ...commonErrors },
});
registry.registerPath({
  method: 'get', path: '/api/v1/price-alerts', tags: ['Price Alerts'], security: secured, summary: 'List active alerts',
  request: { query: ListQuery },
  responses: { 200: { description: 'OK', ...json(z.array(Alert)) }, ...commonErrors },
});
registry.registerPath({
  method: 'delete', path: '/api/v1/price-alerts/{id}', tags: ['Price Alerts'], security: secured, summary: 'Delete an alert',
  request: { params: IdParams },
  responses: { 204: { description: 'Deleted' }, 404: { description: 'Not found', ...json(ErrorResponse) }, ...commonErrors },
});
