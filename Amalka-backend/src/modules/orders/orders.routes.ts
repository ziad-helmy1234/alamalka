import { Router } from 'express';
import { env } from '../../config/env';
import { commonErrors, ErrorResponse, registry, secured, z } from '../../docs/registry';
import { BadRequest } from '../../lib/errors';
import { requireAuth } from '../../middleware/auth';
import { rateLimit } from '../../middleware/rateLimit';
import { validate } from '../../middleware/validate';
import { EditOrderBody, ListOrdersQuery, OrderDto, OrderIdParams, PlaceOrderBody } from './orders.schemas';
import * as svc from './orders.service';

export const ordersRouter = Router();
ordersRouter.use(requireAuth);

const orderLimiter = rateLimit({ name: 'orders', limit: env.RATE_LIMIT_ORDERS_PER_MIN, key: (req) => req.user!.id });
const IDEM_RE = /^[A-Za-z0-9_-]{8,64}$/;

ordersRouter.post('/', orderLimiter, validate({ body: PlaceOrderBody }), async (req, res) => {
  const userId = req.user!.id;
  const idemKey = req.get('Idempotency-Key');
  if (idemKey !== undefined && !IDEM_RE.test(idemKey)) {
    throw BadRequest('INVALID_IDEMPOTENCY_KEY', 'Idempotency-Key must be 8-64 chars of [A-Za-z0-9_-]');
  }

  if (idemKey) {
    const previous = await svc.claimIdempotencyKey(userId, idemKey);
    if (previous) {
      res.setHeader('Idempotent-Replayed', 'true');
      res.status(200).json(await svc.getOrder(userId, previous));
      return;
    }
  }

  try {
    const order = await svc.placeOrder(userId, req.valid.body);
    if (idemKey) await svc.completeIdempotencyKey(userId, idemKey, order.id);
    res.status(201).json(order);
  } catch (err) {
    if (idemKey) await svc.completeIdempotencyKey(userId, idemKey, null).catch(() => undefined);
    throw err;
  }
});

ordersRouter.get('/', validate({ query: ListOrdersQuery }), async (req, res) => {
  res.json(await svc.listOrders(req.user!.id, req.valid.query));
});

ordersRouter.get('/:id', validate({ params: OrderIdParams }), async (req, res) => {
  res.json(await svc.getOrder(req.user!.id, req.valid.params.id));
});

ordersRouter.put('/:id', orderLimiter, validate({ params: OrderIdParams, body: EditOrderBody }), async (req, res) => {
  res.json(await svc.editOrder(req.user!.id, req.valid.params.id, req.valid.body));
});

ordersRouter.delete('/:id', orderLimiter, validate({ params: OrderIdParams }), async (req, res) => {
  res.json(await svc.cancelOrder(req.user!.id, req.valid.params.id));
});

// ---- OpenAPI ----
const json = <T extends z.ZodTypeAny>(schema: T) => ({ content: { 'application/json': { schema } } });
const err = (d: string) => ({ description: d, ...json(ErrorResponse) });
const base = '/api/v1/orders';

registry.registerPath({
  method: 'post', path: base, tags: ['Orders'], security: secured,
  summary: 'Place an order',
  description:
    'BUY orders atomically reserve buying power (price × qty × (1+fee); MARKET orders add a slippage buffer). ' +
    'SELL orders reserve shares. Rows are locked with SELECT … FOR UPDATE so concurrent requests cannot overspend. ' +
    'Send an `Idempotency-Key` header to make retries safe.',
  request: {
    headers: z.object({ 'Idempotency-Key': z.string().optional() }),
    body: json(PlaceOrderBody),
  },
  responses: {
    201: { description: 'Order accepted (status reflects any immediate execution)', ...json(OrderDto) },
    200: { description: 'Idempotent replay of an earlier request', ...json(OrderDto) },
    404: err('Unknown symbol'),
    422: err('INSUFFICIENT_BUYING_POWER / INSUFFICIENT_SHARES / PRICE_OUT_OF_BAND / INVALID_TICK / MARKET_CLOSED …'),
    ...commonErrors,
  },
});
registry.registerPath({
  method: 'get', path: base, tags: ['Orders'], security: secured, summary: 'Order history',
  request: { query: ListOrdersQuery },
  responses: {
    200: { description: 'OK', ...json(z.object({ items: z.array(OrderDto), page: z.number(), limit: z.number(), total: z.number() })) },
    ...commonErrors,
  },
});
registry.registerPath({
  method: 'get', path: `${base}/{id}`, tags: ['Orders'], security: secured, summary: 'Order details with executions',
  request: { params: OrderIdParams },
  responses: { 200: { description: 'OK', ...json(OrderDto) }, 404: err('Not found'), ...commonErrors },
});
registry.registerPath({
  method: 'put', path: `${base}/{id}`, tags: ['Orders'], security: secured,
  summary: 'Modify an open LIMIT order (re-reserves buying power / shares for the difference)',
  request: { params: OrderIdParams, body: json(EditOrderBody) },
  responses: { 200: { description: 'OK', ...json(OrderDto) }, 409: err('Order not open / not editable'), 422: err('Insufficient funds or invalid change'), ...commonErrors },
});
registry.registerPath({
  method: 'delete', path: `${base}/{id}`, tags: ['Orders'], security: secured,
  summary: 'Cancel an open order and release its reserved buying power / shares',
  request: { params: OrderIdParams },
  responses: { 200: { description: 'Cancelled', ...json(OrderDto) }, 409: err('Order not open'), ...commonErrors },
});
