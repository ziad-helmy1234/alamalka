import type { Order, Portfolio, Trade, Transfer } from '@prisma/client';
import { toStr } from '../lib/money';

export function orderDto(o: Order) {
  return {
    id: o.id,
    symbol: o.symbol,
    side: o.side,
    type: o.type,
    targetPrice: toStr(o.targetPrice),
    quantity: o.quantity,
    filledQuantity: o.filledQuantity,
    remainingQuantity: o.status === 'CANCELLED' ? 0 : o.quantity - o.filledQuantity,
    minimumBlockQuantity: o.minimumBlockQuantity,
    validity: o.validity,
    validUntilDate: o.validUntilDate ? o.validUntilDate.toISOString().slice(0, 10) : null,
    executionRule: o.executionRule,
    custodianBank: o.custodianBank,
    currency: o.currency,
    status: o.status,
    lockedAmount: toStr(o.lockedAmount),
    averageFillPrice: toStr(o.averageFillPrice),
    cancelReason: o.cancelReason,
    createdAt: o.createdAt.toISOString(),
    updatedAt: o.updatedAt.toISOString(),
  };
}

export function tradeDto(t: Trade) {
  return {
    id: t.id,
    orderId: t.orderId,
    symbol: t.symbol,
    side: t.side,
    quantity: t.quantity,
    price: toStr(t.price),
    fee: toStr(t.fee),
    executedAt: t.executedAt.toISOString(),
  };
}

export function walletDto(p: Portfolio) {
  return {
    currency: p.currency,
    cashBalance: toStr(p.cashBalance),
    buyingPower: toStr(p.buyingPower),
    lockedAmount: toStr(p.cashBalance.minus(p.buyingPower)),
  };
}

const mask = (s: string | null) => (s ? `${'•'.repeat(Math.max(0, s.length - 4))}${s.slice(-4)}` : null);

export function transferDto(t: Transfer) {
  return {
    id: t.id,
    amount: toStr(t.amount),
    currency: t.currency,
    type: t.type,
    method: t.method,
    destination: mask(t.destination),
    provider: t.provider,
    status: t.status,
    failureReason: t.failureReason,
    createdAt: t.createdAt.toISOString(),
    updatedAt: t.updatedAt.toISOString(),
  };
}
