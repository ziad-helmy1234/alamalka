import { env } from '../../config/env';
import { CurrencyEnum, z } from '../../docs/registry';

const price = z
  .union([z.number(), z.string()])
  .transform((v) => String(v))
  .refine((v) => /^\d+(\.\d{1,3})?$/.test(v) && Number(v) > 0, 'Price must be positive with at most 3 decimals')
  .openapi({ type: 'string', example: '82.50' });

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD').openapi({ example: '2026-11-15' });
const qty = z.number().int().positive().max(env.MAX_ORDER_QUANTITY);

export const SideEnum = z.enum(['BUY', 'SELL']).openapi('OrderSide');
export const TypeEnum = z.enum(['MARKET', 'LIMIT']).openapi('OrderType');
export const ValidityEnum = z.enum(['DAY', 'GTC', 'GTD']).openapi('OrderValidity');
export const RuleEnum = z
  .enum(['REGULAR', 'MF', 'FOK', 'FAK', 'AON'])
  .openapi('ExecutionRule', {
    description:
      'REGULAR: normal. MF: minimum fill on entry (needs minimumBlockQuantity). FOK: fill all now or cancel. FAK: fill what is available now, cancel rest. AON: execute only the full quantity at once.',
  });
export const StatusEnum = z.enum(['PENDING', 'PARTIALLY_FILLED', 'EXECUTED', 'CANCELLED']).openapi('OrderStatus');

export const PlaceOrderBody = z
  .object({
    symbol: z.string().trim().toUpperCase().min(1).max(16).openapi({ example: 'COMI' }),
    side: SideEnum,
    type: TypeEnum,
    targetPrice: price.optional().openapi({ description: 'Required for LIMIT, omit for MARKET' }),
    quantity: qty.openapi({ example: 100 }),
    minimumBlockQuantity: qty.optional().openapi({ description: 'Conditional order (تنفيذ بالدفعات) / MF minimum' }),
    validity: ValidityEnum.default('DAY'),
    validUntilDate: isoDate.optional().openapi({ description: 'Required for GTD' }),
    executionRule: RuleEnum.default('REGULAR'),
    custodianBank: z.string().trim().min(2).max(80).openapi({ example: 'CIB Custody' }),
    currency: CurrencyEnum.optional().openapi({ description: "Defaults to the stock's trading currency" }),
  })
  .strict()
  .superRefine((b, ctx) => {
    const issue = (path: string, message: string) => ctx.addIssue({ code: 'custom', path: [path], message });
    if (b.type === 'LIMIT' && !b.targetPrice) issue('targetPrice', 'targetPrice is required for LIMIT orders');
    if (b.type === 'MARKET' && b.targetPrice) issue('targetPrice', 'MARKET orders must not have a targetPrice');
    if (b.type === 'MARKET' && b.validity !== 'DAY') issue('validity', 'MARKET orders are DAY orders');
    if (b.validity === 'GTD' && !b.validUntilDate) issue('validUntilDate', 'validUntilDate is required for GTD');
    if (b.validity !== 'GTD' && b.validUntilDate) issue('validUntilDate', 'validUntilDate is only allowed for GTD');
    if ((b.executionRule === 'FOK' || b.executionRule === 'FAK') && b.validity !== 'DAY') {
      issue('validity', `${b.executionRule} orders are immediate and must be DAY`);
    }
    if (b.executionRule === 'MF' && !b.minimumBlockQuantity) issue('minimumBlockQuantity', 'MF orders need minimumBlockQuantity');
    if (b.minimumBlockQuantity && b.minimumBlockQuantity > b.quantity) {
      issue('minimumBlockQuantity', 'minimumBlockQuantity cannot exceed quantity');
    }
  })
  .openapi('PlaceOrderRequest');

export const EditOrderBody = z
  .object({
    targetPrice: price.optional(),
    quantity: qty.optional().openapi({ description: 'New TOTAL quantity (must exceed already-filled quantity)' }),
    minimumBlockQuantity: qty.nullable().optional(),
    validity: ValidityEnum.optional(),
    validUntilDate: isoDate.nullable().optional(),
  })
  .strict()
  .refine((b) => Object.keys(b).length > 0, 'Nothing to update')
  .openapi('EditOrderRequest');

export const OrderIdParams = z.object({ id: z.string().regex(/^ORD-\d{1,18}$/, 'Invalid order id') });

export const ListOrdersQuery = z.object({
  status: z.union([StatusEnum, z.literal('OPEN')]).optional().openapi({ description: 'OPEN = PENDING or PARTIALLY_FILLED' }),
  symbol: z.string().trim().toUpperCase().max(16).optional(),
  side: SideEnum.optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export const OrderDto = z
  .object({
    id: z.string().openapi({ example: 'ORD-100001' }),
    symbol: z.string(),
    side: SideEnum,
    type: TypeEnum,
    targetPrice: z.string().nullable(),
    quantity: z.number(),
    filledQuantity: z.number(),
    remainingQuantity: z.number(),
    minimumBlockQuantity: z.number().nullable(),
    validity: ValidityEnum,
    validUntilDate: z.string().nullable(),
    executionRule: RuleEnum,
    custodianBank: z.string(),
    currency: CurrencyEnum,
    status: StatusEnum,
    lockedAmount: z.string(),
    averageFillPrice: z.string().nullable(),
    cancelReason: z.string().nullable(),
    createdAt: z.string(),
    updatedAt: z.string(),
  })
  .openapi('Order');
