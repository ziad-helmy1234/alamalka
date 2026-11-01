import type { ExecutionRule, Order, OrderType, Prisma, Trade } from '@prisma/client';
import { env } from '../config/env';
import { logger } from '../lib/logger';
import { prisma, withTx } from '../lib/prisma';
import { isMarketOpen } from '../market/session';
import type { ExecutionVenue, Fill } from '../market/venue';
import { CHANNELS, publish, publishToUser, type TickPayload } from '../realtime/events';
import { orderDto, tradeDto, walletDto } from './dto';
import { applyFills, cancelRemainder, isOpen, lockOrder, OPEN_STATUSES, remainingOf } from './settlement';

export interface Decision {
  take: number;
  cancelRest: boolean;
  reason?: string;
}

type DecideInput = Pick<Order, 'quantity' | 'filledQuantity' | 'minimumBlockQuantity'> & {
  executionRule: ExecutionRule;
  type: OrderType;
};

/**
 * EGX execution-condition logic (pure — unit tested).
 * `available` = quantity the venue can fill right now within the order's price limit.
 * `isEntry`   = first evaluation, right after the order reaches the market.
 */
export function decide(o: DecideInput, available: number, isEntry: boolean): Decision {
  const remaining = o.quantity - o.filledQuantity;
  const avail = Math.min(available, remaining);
  const isMarket = o.type === 'MARKET';
  const marketRest = 'Market order: no further liquidity, remainder cancelled';

  switch (o.executionRule) {
    case 'FOK':
      return avail >= remaining
        ? { take: remaining, cancelRest: false }
        : { take: 0, cancelRest: true, reason: 'FOK: full quantity not available, order killed' };
    case 'FAK':
      return { take: avail, cancelRest: true, reason: 'FAK: unfilled remainder cancelled' };
    case 'AON':
      if (avail >= remaining) return { take: remaining, cancelRest: false };
      return { take: 0, cancelRest: isMarket, reason: 'AON: full quantity not available' };
    case 'MF':
      if (isEntry && o.filledQuantity === 0) {
        const need = Math.min(o.minimumBlockQuantity ?? remaining, remaining);
        if (avail < need) return { take: 0, cancelRest: true, reason: 'MF: minimum fill quantity not available' };
        return { take: avail, cancelRest: isMarket, reason: marketRest };
      }
      // After the entry check an MF order behaves like a regular order.
      return { take: avail, cancelRest: isMarket, reason: marketRest };
    case 'REGULAR':
    default: {
      // Conditional order (تنفيذ بالدفعات): every execution must be at least the minimum block.
      const block = o.minimumBlockQuantity ? Math.min(o.minimumBlockQuantity, remaining) : 1;
      return { take: avail >= block ? avail : 0, cancelRest: isMarket, reason: marketRest };
    }
  }
}

/** Orders that must be resolved immediately and never rest in the book. */
const isImmediate = (o: Pick<Order, 'executionRule' | 'type'>) =>
  o.executionRule === 'FOK' || o.executionRule === 'FAK' || o.type === 'MARKET';

function trim(fills: Fill[], qty: number): Fill[] {
  const out: Fill[] = [];
  let left = qty;
  for (const f of fills) {
    if (left <= 0) break;
    const q = Math.min(f.quantity, left);
    out.push({ price: f.price, quantity: q });
    left -= q;
  }
  return out;
}

export class MatchingEngine {
  private venue: ExecutionVenue | null = null;
  private busy = false;
  /** True on the instance that owns the venue (leader). Others forward new orders via Redis. */
  get active(): boolean {
    return this.venue !== null;
  }

  setVenue(venue: ExecutionVenue | null): void {
    this.venue = venue;
  }

  /** Route a new or edited order to the matching engine (inline on the leader, via Redis otherwise). */
  async submit(orderId: string, isEntry: boolean): Promise<void> {
    if (this.active) {
      await this.process(orderId, isEntry);
    } else {
      await publish(CHANNELS.newOrder, { orderId, isEntry });
    }
  }

  async process(orderId: string, isEntry: boolean): Promise<void> {
    const snap = await prisma.order.findUnique({ where: { id: orderId } });
    if (!snap || !isOpen(snap)) return;

    const closed = env.ENFORCE_MARKET_HOURS && !isMarketOpen();
    if (!this.venue || closed) {
      if (isEntry && isImmediate(snap)) {
        await this.cancel(orderId, closed ? 'Market is closed' : 'No execution venue available');
      }
      return;
    }

    const remaining = remainingOf(snap);
    const fills = this.venue.peek(snap.symbol, snap.side, snap.type === 'LIMIT' ? snap.targetPrice : null, remaining);
    const available = fills.reduce((s, f) => s + f.quantity, 0);
    const plan = decide(snap, available, isEntry);
    if (plan.take === 0 && !plan.cancelRest) return;
    const toFill = trim(fills, plan.take);
    const allOrNothing = snap.executionRule === 'FOK' || snap.executionRule === 'AON';

    const result = await withTx(async (tx) => {
      const order = await lockOrder(tx, orderId);
      // Re-check under lock: if the order changed since we priced it, skip — the next tick re-evaluates.
      if (
        !order ||
        !isOpen(order) ||
        order.filledQuantity !== snap.filledQuantity ||
        order.quantity !== snap.quantity ||
        String(order.targetPrice) !== String(snap.targetPrice)
      ) {
        return null;
      }
      let current = order;
      let trades: Trade[] = [];
      let applied: Fill[] = [];
      let cancelReason = plan.reason;
      if (toFill.length > 0) {
        const r = await applyFills(tx, order, toFill, allOrNothing);
        current = r.order;
        trades = r.trades;
        applied = r.applied;
        if (r.unaffordable) cancelReason = 'Insufficient buying power at execution price';
      }
      const mustCancel = plan.cancelRest || (allOrNothing && applied.length === 0 && toFill.length > 0 && isImmediate(current));
      if (mustCancel && isOpen(current) && remainingOf(current) > 0) {
        current = await cancelRemainder(tx, current, cancelReason ?? 'Cancelled');
      }
      return { order: current, trades, applied, changed: current !== order };
    });

    if (!result || !result.changed) return;
    if (result.applied.length) this.venue?.consume(snap.symbol, snap.side, result.applied);
    await this.emit(result.order, result.trades);
  }

  /** Cancel an order outright (used for immediate orders that cannot reach the market). */
  private async cancel(orderId: string, reason: string): Promise<void> {
    const order = await withTx(async (tx) => {
      const o = await lockOrder(tx, orderId);
      if (!o || !isOpen(o)) return null;
      return cancelRemainder(tx, o, reason);
    });
    if (order) await this.emit(order, []);
  }

  async emit(order: Order, trades: Trade[]): Promise<void> {
    await publishToUser(order.userId, { type: 'order_update', data: orderDto(order) });
    for (const t of trades) await publishToUser(order.userId, { type: 'trade_execution', data: tradeDto(t) });
    const wallet = await prisma.portfolio.findUnique({ where: { id: order.portfolioId } });
    if (wallet) await publishToUser(order.userId, { type: 'wallet_update', data: walletDto(wallet) });
  }

  /** On every market tick, try the resting orders that have become marketable. */
  async onTicks(ticks: TickPayload[]): Promise<void> {
    if (this.busy || !this.venue) return;
    this.busy = true;
    try {
      const or: Prisma.OrderWhereInput[] = [];
      for (const t of ticks) {
        if (t.ask) or.push({ symbol: t.symbol, side: 'BUY', OR: [{ type: 'MARKET' }, { targetPrice: { gte: t.ask } }] });
        if (t.bid) or.push({ symbol: t.symbol, side: 'SELL', OR: [{ type: 'MARKET' }, { targetPrice: { lte: t.bid } }] });
      }
      if (or.length === 0) return;
      const candidates = await prisma.order.findMany({
        where: { status: { in: [...OPEN_STATUSES] }, OR: or },
        orderBy: { createdAt: 'asc' }, // time priority
        select: { id: true },
        take: 500,
      });
      for (const c of candidates) {
        await this.process(c.id, false).catch((err) => logger.error({ err, orderId: c.id }, 'order processing failed'));
      }
    } finally {
      this.busy = false;
    }
  }
}

export const engine = new MatchingEngine();
