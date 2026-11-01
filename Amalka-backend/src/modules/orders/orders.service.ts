import type { Currency, ExecutionRule, OrderSide, OrderStatus, OrderType, OrderValidity, Prisma } from '@prisma/client';
import { custodianBanks, env } from '../../config/env';
import { AppError, Conflict, NotFound, Unprocessable } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { D, type Dec } from '../../lib/money';
import { prisma, withTx } from '../../lib/prisma';
import { redis } from '../../lib/redis';
import { getQuotes } from '../../market/quotes';
import { isOnTick, priceBand } from '../../market/rules';
import { isMarketOpen, todayLocal } from '../../market/session';
import { orderDto } from '../../oms/dto';
import { engine } from '../../oms/engine';
import { cancelRemainder, isOpen, lockAmountFor, lockOrder, lockPortfolio, OPEN_STATUSES, remainingOf } from '../../oms/settlement';

export interface PlaceOrderInput {
  symbol: string;
  side: OrderSide;
  type: OrderType;
  targetPrice?: string;
  quantity: number;
  minimumBlockQuantity?: number;
  validity: OrderValidity;
  validUntilDate?: string;
  executionRule: ExecutionRule;
  custodianBank: string;
  currency?: Currency;
}

/** Latest price + previous close, preferring the live cache over the DB snapshot. */
async function referencePrices(symbol: string) {
  const stock = await prisma.stock.findUnique({ where: { symbol } });
  if (!stock || !stock.isActive) throw NotFound(`Stock ${symbol}`);
  const live = (await getQuotes([symbol])).get(symbol);
  return {
    stock,
    last: live ? D(live.price) : stock.currentPrice,
    previousClose: live ? D(live.previousClose) : stock.previousClose,
  };
}

function checkLimitPrice(price: Dec, previousClose: Dec): void {
  if (!isOnTick(price)) throw Unprocessable('INVALID_TICK', 'Price is not a multiple of the tick size');
  const band = priceBand(previousClose);
  if (price.lt(band.min) || price.gt(band.max)) {
    throw Unprocessable('PRICE_OUT_OF_BAND', `Limit price must be between ${band.min.toFixed(2)} and ${band.max.toFixed(2)}`, {
      min: band.min.toFixed(4),
      max: band.max.toFixed(4),
    });
  }
}

function checkGtdDate(validUntil: string | null | undefined): void {
  if (!validUntil) return;
  const today = todayLocal();
  if (validUntil < today) throw Unprocessable('INVALID_GTD_DATE', 'validUntilDate cannot be in the past');
  const max = new Date(`${today}T00:00:00Z`);
  max.setUTCFullYear(max.getUTCFullYear() + 1);
  if (validUntil > max.toISOString().slice(0, 10)) throw Unprocessable('INVALID_GTD_DATE', 'validUntilDate must be within one year');
}

export async function placeOrder(userId: string, input: PlaceOrderInput) {
  if (!custodianBanks.includes(input.custodianBank)) {
    throw Unprocessable('INVALID_CUSTODIAN', 'Unknown custodian bank', { allowed: custodianBanks });
  }
  const { stock, last, previousClose } = await referencePrices(input.symbol);
  if (input.currency && input.currency !== stock.currency) {
    throw Unprocessable('CURRENCY_MISMATCH', `${stock.symbol} trades in ${stock.currency}`);
  }
  const limit = input.type === 'LIMIT' ? D(input.targetPrice!) : null;
  if (limit) checkLimitPrice(limit, previousClose);
  checkGtdDate(input.validUntilDate);
  if (env.ENFORCE_MARKET_HOURS && !isMarketOpen() && (input.type === 'MARKET' || input.executionRule === 'FOK' || input.executionRule === 'FAK')) {
    throw Unprocessable('MARKET_CLOSED', 'Market and immediate (FOK/FAK) orders are only accepted during the trading session');
  }

  const order = await withTx(async (tx) => {
    const wallet = await tx.portfolio.findUnique({ where: { userId_currency: { userId, currency: stock.currency } } });
    if (!wallet) throw NotFound(`${stock.currency} wallet`);
    const portfolio = await lockPortfolio(tx, wallet.id);

    let lockedAmount = D(0);
    if (input.side === 'BUY') {
      lockedAmount = lockAmountFor('BUY', input.type, input.quantity, limit, last);
      if (portfolio.buyingPower.lt(lockedAmount)) {
        throw Unprocessable('INSUFFICIENT_BUYING_POWER', 'Insufficient buying power for this order', {
          required: lockedAmount.toFixed(2),
          available: portfolio.buyingPower.toFixed(2),
        });
      }
      await tx.portfolio.update({ where: { id: portfolio.id }, data: { buyingPower: { decrement: lockedAmount } } });
    } else {
      const holding = await tx.holding.findUnique({ where: { portfolioId_symbol: { portfolioId: portfolio.id, symbol: stock.symbol } } });
      const free = holding ? holding.quantity - holding.reservedQuantity : 0;
      if (!holding || free < input.quantity) {
        throw Unprocessable('INSUFFICIENT_SHARES', `You can sell at most ${free} shares of ${stock.symbol}`, { available: free });
      }
      await tx.holding.update({ where: { id: holding.id }, data: { reservedQuantity: { increment: input.quantity } } });
    }

    return tx.order.create({
      data: {
        userId,
        portfolioId: portfolio.id,
        symbol: stock.symbol,
        side: input.side,
        type: input.type,
        targetPrice: limit,
        quantity: input.quantity,
        minimumBlockQuantity: input.minimumBlockQuantity ?? null,
        validity: input.validity,
        validUntilDate: input.validUntilDate ? new Date(`${input.validUntilDate}T00:00:00Z`) : null,
        executionRule: input.executionRule,
        custodianBank: input.custodianBank,
        currency: stock.currency,
        lockedAmount,
      },
    });
  });

  await engine.emit(order, []);
  // The order is committed; an engine hiccup must not fail the request (the next tick / expiry job picks it up).
  await engine.submit(order.id, true).catch((err) => logger.error({ err, orderId: order.id }, 'engine submit failed'));
  return orderDto(await prisma.order.findUniqueOrThrow({ where: { id: order.id } }));
}

export interface EditOrderInput {
  targetPrice?: string;
  quantity?: number;
  minimumBlockQuantity?: number | null;
  validity?: OrderValidity;
  validUntilDate?: string | null;
}

export async function editOrder(userId: string, orderId: string, patch: EditOrderInput) {
  const updated = await withTx(async (tx) => {
    const order = await lockOrder(tx, orderId);
    if (!order || order.userId !== userId) throw NotFound('Order');
    if (!isOpen(order)) throw Conflict('ORDER_NOT_OPEN', `Order is ${order.status} and can no longer be modified`);
    if (order.type === 'MARKET') throw Conflict('ORDER_NOT_EDITABLE', 'MARKET orders cannot be modified');
    if (order.executionRule === 'FOK' || order.executionRule === 'FAK') throw Conflict('ORDER_NOT_EDITABLE', 'Immediate orders cannot be modified');

    const newPrice = patch.targetPrice ? D(patch.targetPrice) : order.targetPrice!;
    const newQty = patch.quantity ?? order.quantity;
    const newMinBlock = patch.minimumBlockQuantity === undefined ? order.minimumBlockQuantity : patch.minimumBlockQuantity;
    const newValidity = patch.validity ?? order.validity;
    let newUntil: string | null =
      patch.validUntilDate === undefined ? (order.validUntilDate?.toISOString().slice(0, 10) ?? null) : patch.validUntilDate;
    if (newValidity !== 'GTD') newUntil = null;

    if (newQty <= order.filledQuantity) {
      throw Unprocessable('INVALID_QUANTITY', `Quantity must be greater than the ${order.filledQuantity} shares already filled`);
    }
    if (newValidity === 'GTD' && !newUntil) throw Unprocessable('INVALID_GTD_DATE', 'validUntilDate is required for GTD');
    if (newUntil && newUntil !== order.validUntilDate?.toISOString().slice(0, 10)) checkGtdDate(newUntil);
    if (order.executionRule === 'MF' && !newMinBlock) throw Unprocessable('INVALID_MIN_BLOCK', 'MF orders need minimumBlockQuantity');
    if (newMinBlock && newMinBlock > newQty) throw Unprocessable('INVALID_MIN_BLOCK', 'minimumBlockQuantity cannot exceed quantity');
    if (patch.targetPrice) {
      const { previousClose } = await referencePrices(order.symbol);
      checkLimitPrice(newPrice, previousClose);
    }

    const newRemaining = newQty - order.filledQuantity;
    const data: Prisma.OrderUpdateInput = {
      targetPrice: newPrice,
      quantity: newQty,
      minimumBlockQuantity: newMinBlock,
      validity: newValidity,
      validUntilDate: newUntil ? new Date(`${newUntil}T00:00:00Z`) : null,
    };

    const portfolio = await lockPortfolio(tx, order.portfolioId);
    if (order.side === 'BUY') {
      const newLock = lockAmountFor('BUY', 'LIMIT', newRemaining, newPrice, newPrice);
      const delta = newLock.minus(order.lockedAmount);
      if (delta.gt(0) && portfolio.buyingPower.lt(delta)) {
        throw Unprocessable('INSUFFICIENT_BUYING_POWER', 'Insufficient buying power for the modified order', {
          required: delta.toFixed(2),
          available: portfolio.buyingPower.toFixed(2),
        });
      }
      if (!delta.isZero()) {
        await tx.portfolio.update({ where: { id: portfolio.id }, data: { buyingPower: { decrement: delta } } });
      }
      data.lockedAmount = newLock;
    } else {
      const delta = newRemaining - remainingOf(order);
      if (delta !== 0) {
        const holding = await tx.holding.findUniqueOrThrow({
          where: { portfolioId_symbol: { portfolioId: portfolio.id, symbol: order.symbol } },
        });
        if (delta > 0 && holding.quantity - holding.reservedQuantity < delta) {
          throw Unprocessable('INSUFFICIENT_SHARES', 'Not enough free shares to increase this sell order', {
            available: holding.quantity - holding.reservedQuantity,
          });
        }
        await tx.holding.update({ where: { id: holding.id }, data: { reservedQuantity: { increment: delta } } });
      }
    }
    return tx.order.update({ where: { id: order.id }, data });
  });

  await engine.emit(updated, []);
  await engine.submit(updated.id, false).catch((err) => logger.error({ err, orderId: updated.id }, 'engine submit failed'));
  return orderDto(await prisma.order.findUniqueOrThrow({ where: { id: updated.id } }));
}

export async function cancelOrder(userId: string, orderId: string) {
  const order = await withTx(async (tx) => {
    const o = await lockOrder(tx, orderId);
    if (!o || o.userId !== userId) throw NotFound('Order');
    if (!isOpen(o)) throw Conflict('ORDER_NOT_OPEN', `Order is ${o.status} and cannot be cancelled`);
    return cancelRemainder(tx, o, 'Cancelled by user');
  });
  await engine.emit(order, []);
  return orderDto(order);
}

export async function listOrders(
  userId: string,
  q: { status?: OrderStatus | 'OPEN'; symbol?: string; side?: OrderSide; page: number; limit: number },
) {
  const where: Prisma.OrderWhereInput = {
    userId,
    symbol: q.symbol,
    side: q.side,
    status: q.status === 'OPEN' ? { in: [...OPEN_STATUSES] } : q.status,
  };
  const [items, total] = await Promise.all([
    prisma.order.findMany({ where, orderBy: { createdAt: 'desc' }, skip: (q.page - 1) * q.limit, take: q.limit }),
    prisma.order.count({ where }),
  ]);
  return { items: items.map(orderDto), page: q.page, limit: q.limit, total };
}

export async function getOrder(userId: string, orderId: string) {
  const order = await prisma.order.findUnique({ where: { id: orderId }, include: { trades: { orderBy: { executedAt: 'asc' } } } });
  if (!order || order.userId !== userId) throw NotFound('Order');
  return {
    ...orderDto(order),
    trades: order.trades.map((t) => ({ id: t.id, quantity: t.quantity, price: t.price.toFixed(4), fee: t.fee.toFixed(4), executedAt: t.executedAt.toISOString() })),
  };
}

// ---------------- Idempotency (safe retries from flaky mobile networks) ----------------

const IDEM_TTL = 24 * 3600;

/** Returns the order id from a previous request with the same key, or null if this is the first. */
export async function claimIdempotencyKey(userId: string, key: string): Promise<string | null> {
  const k = `idem:order:${userId}:${key}`;
  const claimed = await redis.set(k, 'pending', 'EX', IDEM_TTL, 'NX');
  if (claimed === 'OK') return null;
  const existing = await redis.get(k);
  if (!existing || existing === 'pending') throw new AppError(409, 'REQUEST_IN_PROGRESS', 'A request with this Idempotency-Key is still being processed');
  return existing;
}

export async function completeIdempotencyKey(userId: string, key: string, orderId: string | null): Promise<void> {
  const k = `idem:order:${userId}:${key}`;
  if (orderId) await redis.set(k, orderId, 'EX', IDEM_TTL);
  else await redis.del(k);
}
