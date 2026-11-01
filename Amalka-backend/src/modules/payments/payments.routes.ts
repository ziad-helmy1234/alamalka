import { Router, type Request, type Response } from 'express';
import { CurrencyEnum, commonErrors, ErrorResponse, money, registry, secured, z } from '../../docs/registry';
import { BadRequest } from '../../lib/errors';
import { requireAuth, requireRole } from '../../middleware/auth';
import { validate } from '../../middleware/validate';
import * as svc from './payments.service';

export const paymentsRouter = Router();

const CardIntentBody = z
  .object({
    amount: money,
    currency: CurrencyEnum.default('EGP'),
    provider: z.enum(['paymob', 'paytabs']).optional(),
    phone: z.string().regex(/^\+?\d{8,15}$/).optional().openapi({ example: '+201001234567' }),
  })
  .strict()
  .openapi('CardIntentRequest');

const WithdrawalBody = z
  .object({
    amount: money,
    currency: CurrencyEnum.default('EGP'),
    method: z.enum(['Bank Transfer', 'InstaPay']),
    destination: z.string().trim().min(4).max(64).openapi({ description: 'IBAN or InstaPay address', example: 'EG380019000500000000263180002' }),
  })
  .strict()
  .openapi('WithdrawalRequest');

const PageQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  type: z.enum(['DEPOSIT', 'WITHDRAWAL']).optional(),
});
const TransferParams = z.object({ id: z.string().regex(/^TRF-\d{1,18}$/) });
const RejectBody = z.object({ reason: z.string().trim().max(200).optional() }).strict();

/**
 * Mounted in app.ts BEFORE express.json(): signatures are computed over the exact raw bytes.
 * Returns 200 for every correctly signed callback (including duplicates) so the gateway stops retrying.
 */
export async function webhookHandler(req: Request, res: Response): Promise<void> {
  if (!Buffer.isBuffer(req.body) || req.body.length === 0) throw BadRequest('INVALID_PAYLOAD', 'Empty body');
  res.json(await svc.handleWebhook(req.body, req.query as Record<string, unknown>, req.headers as Record<string, unknown>));
}

paymentsRouter.post('/card-intent', requireAuth, validate({ body: CardIntentBody }), async (req, res) => {
  res.status(201).json(await svc.createCardIntent(req.user!.id, req.valid.body));
});

paymentsRouter.get('/transfers', requireAuth, validate({ query: PageQuery }), async (req, res) => {
  res.json(await svc.listTransfers(req.user!.id, req.valid.query));
});

paymentsRouter.post('/withdrawals', requireAuth, validate({ body: WithdrawalBody }), async (req, res) => {
  res.status(201).json(await svc.requestWithdrawal(req.user!.id, req.valid.body));
});

// ---- Admin back-office ----
paymentsRouter.get('/admin/withdrawals', requireAuth, requireRole('ADMIN'), async (_req, res) => {
  res.json(await svc.listPendingWithdrawals());
});
paymentsRouter.post('/admin/withdrawals/:id/approve', requireAuth, requireRole('ADMIN'), validate({ params: TransferParams }), async (req, res) => {
  res.json(await svc.resolveWithdrawal(req.valid.params.id, true));
});
paymentsRouter.post(
  '/admin/withdrawals/:id/reject',
  requireAuth,
  requireRole('ADMIN'),
  validate({ params: TransferParams, body: RejectBody }),
  async (req, res) => {
    res.json(await svc.resolveWithdrawal(req.valid.params.id, false, req.valid.body.reason));
  },
);

// ---- OpenAPI ----
const json = <T extends z.ZodTypeAny>(schema: T) => ({ content: { 'application/json': { schema } } });
const Transfer = z
  .object({
    id: z.string().openapi({ example: 'TRF-100001' }), amount: z.string(), currency: CurrencyEnum,
    type: z.enum(['DEPOSIT', 'WITHDRAWAL']), method: z.string(), destination: z.string().nullable(),
    provider: z.string().nullable(), status: z.enum(['PENDING', 'COMPLETED', 'FAILED']),
    failureReason: z.string().nullable(), createdAt: z.string(), updatedAt: z.string(),
  })
  .openapi('Transfer');

registry.registerPath({
  method: 'post', path: '/api/v1/payments/card-intent', tags: ['Payments'], security: secured,
  summary: 'Start a card deposit (Paymob or PayTabs). Open checkoutUrl in a web view; the wallet is credited by the webhook.',
  request: { body: json(CardIntentBody) },
  responses: {
    201: {
      description: 'Created',
      ...json(z.object({
        transferId: z.string(), provider: z.string(), amount: z.string(), currency: CurrencyEnum, status: z.literal('PENDING'),
        checkoutUrl: z.string(), clientSecret: z.string().nullable(),
      })),
    },
    502: { description: 'Gateway error', ...json(ErrorResponse) },
    503: { description: 'Gateway not configured', ...json(ErrorResponse) },
    ...commonErrors,
  },
});
registry.registerPath({
  method: 'post', path: '/api/v1/payments/webhook', tags: ['Payments'],
  summary: 'Gateway callback (HMAC-signed). Paymob: ?hmac= (SHA-512). PayTabs: Signature header (SHA-256 of raw body).',
  request: { query: z.object({ provider: z.enum(['paymob', 'paytabs']).optional(), hmac: z.string().optional() }) },
  responses: {
    200: { description: 'Accepted', ...json(z.object({ received: z.boolean(), outcome: z.string() })) },
    401: { description: 'Bad signature', ...json(ErrorResponse) },
  },
});
registry.registerPath({
  method: 'get', path: '/api/v1/payments/transfers', tags: ['Payments'], security: secured, summary: 'Deposit / withdrawal history',
  request: { query: PageQuery },
  responses: { 200: { description: 'OK', ...json(z.object({ items: z.array(Transfer), page: z.number(), limit: z.number(), total: z.number() })) }, ...commonErrors },
});
registry.registerPath({
  method: 'post', path: '/api/v1/payments/withdrawals', tags: ['Payments'], security: secured,
  summary: 'Request a withdrawal (funds are held immediately, paid out after admin approval)',
  request: { body: json(WithdrawalBody) },
  responses: { 201: { description: 'Created', ...json(Transfer) }, 422: { description: 'Insufficient funds', ...json(ErrorResponse) }, ...commonErrors },
});
registry.registerPath({
  method: 'get', path: '/api/v1/payments/admin/withdrawals', tags: ['Admin'], security: secured, summary: 'Pending withdrawals (ADMIN)',
  responses: { 200: { description: 'OK' }, 403: { description: 'Forbidden', ...json(ErrorResponse) } },
});
registry.registerPath({
  method: 'post', path: '/api/v1/payments/admin/withdrawals/{id}/approve', tags: ['Admin'], security: secured, summary: 'Mark payout done (ADMIN)',
  request: { params: TransferParams },
  responses: { 200: { description: 'OK', ...json(Transfer) }, 409: { description: 'Not pending', ...json(ErrorResponse) } },
});
registry.registerPath({
  method: 'post', path: '/api/v1/payments/admin/withdrawals/{id}/reject', tags: ['Admin'], security: secured, summary: 'Reject and release funds (ADMIN)',
  request: { params: TransferParams, body: json(RejectBody) },
  responses: { 200: { description: 'OK', ...json(Transfer) }, 409: { description: 'Not pending', ...json(ErrorResponse) } },
});
