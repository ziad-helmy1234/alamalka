import type { Order, OrderSide, OrderType, Portfolio, Trade } from '@prisma/client';
import { env } from '../config/env';
import { ceil4, r4, ZERO, type Dec } from '../lib/money';
import { lockRow, type Tx } from '../lib/prisma';
import type { Fill } from '../market/venue';

export const OPEN_STATUSES = ['PENDING', 'PARTIALLY_FILLED'] as const;
export const isOpen = (o: Pick<Order, 'status'>) => (OPEN_STATUSES as readonly string[]).includes(o.status);
export const remainingOf = (o: Pick<Order, 'quantity' | 'filledQuantity'>) => o.quantity - o.filledQuantity;

export const feeFor = (notional: Dec) => r4(notional.times(env.TRADING_FEE_RATE));

/**
 * Buying power to reserve for the unfilled part of a BUY order:
 *   LIMIT : qty × limit × (1 + fee)
 *   MARKET: qty × last × (1 + buffer) × (1 + fee)   (buffer absorbs slippage)
 * Rounded UP so a reservation is never short by a fraction of a piaster.
 */
export function lockAmountFor(side: OrderSide, type: OrderType, qty: number, limit: Dec | null, lastPrice: Dec): Dec {
  if (side === 'SELL' || qty <= 0) return ZERO;
  const px = type === 'LIMIT' && limit ? limit : lastPrice.times(1 + env.MARKET_BUY_BUFFER);
  return ceil4(px.times(qty).times(1 + env.TRADING_FEE_RATE));
}

/** Lock the order row and return its current state (null if missing). */
export async function lockOrder(tx: Tx, orderId: string): Promise<Order | null> {
  if (!(await lockRow(tx, 'orders', orderId))) return null;
  return tx.order.findUnique({ where: { id: orderId } });
}

/** Lock the portfolio row. Holdings of a portfolio are only mutated while this lock is held. */
export async function lockPortfolio(tx: Tx, portfolioId: string): Promise<Portfolio> {
  await lockRow(tx, 'portfolios', portfolioId);
  return tx.portfolio.findUniqueOrThrow({ where: { id: portfolioId } });
}

export interface FillResult {
  order: Order;
  trades: Trade[];
  applied: Fill[];
  /** True when an all-or-nothing fill could not be afforded (MARKET buy that moved beyond its buffer). */
  unaffordable: boolean;
}

/**
 * Settle executions against an order. Caller MUST hold the order lock (lockOrder) and pass
 * the fresh locked row. Moves cash, reservations, holdings, writes trades + ledger, updates order.
 */
export async function applyFills(tx: Tx, order: Order, fills: Fill[], allOrNothing: boolean): Promise<FillResult> {
  let remaining = remainingOf(order);
  const wanted = fills.map((f) => ({ price: f.price, quantity: Math.min(f.quantity, Number.MAX_SAFE_INTEGER) }));

  let portfolio = await lockPortfolio(tx, order.portfolioId);

  // --- affordability (BUY): a MARKET buy may execute above the price it reserved for ---
  if (order.side === 'BUY') {
    const budget = order.lockedAmount.plus(portfolio.buyingPower);
    let spent = ZERO;
    let left = remaining;
    const affordable: Fill[] = [];
    for (const f of wanted) {
      if (left <= 0) break;
      let q = Math.min(f.quantity, left);
      const unit = f.price.times(1 + env.TRADING_FEE_RATE);
      const maxQ = budget.minus(spent).div(unit).floor().toNumber();
      q = Math.min(q, Math.max(0, maxQ));
      if (q <= 0) break;
      const cost = r4(f.price.times(q));
      spent = spent.plus(cost).plus(feeFor(cost));
      affordable.push({ price: f.price, quantity: q });
      left -= q;
    }
    const wantedQty = wanted.reduce((s, f) => s + Math.min(f.quantity, remaining), 0);
    const affordableQty = affordable.reduce((s, f) => s + f.quantity, 0);
    if (allOrNothing && affordableQty < Math.min(wantedQty, remaining)) {
      return { order, trades: [], applied: [], unaffordable: true };
    }
    wanted.splice(0, wanted.length, ...affordable);
  }

  let locked = order.lockedAmount;
  let filled = order.filledQuantity;
  let notional = order.averageFillPrice ? order.averageFillPrice.times(order.filledQuantity) : ZERO;
  const trades: Trade[] = [];
  const applied: Fill[] = [];

  for (const f of wanted) {
    if (remaining <= 0) break;
    const q = Math.min(f.quantity, remaining);
    if (q <= 0) continue;
    const cost = r4(f.price.times(q));
    const fee = feeFor(cost);

    if (order.side === 'BUY') {
      const total = cost.plus(fee);
      // Release the share of the reservation that belonged to these q shares.
      const release = q === remaining ? locked : minDec(r4(locked.times(q).div(remaining)), locked);
      portfolio = await tx.portfolio.update({
        where: { id: portfolio.id },
        data: { cashBalance: { decrement: total }, buyingPower: { increment: release.minus(total) } },
      });
      locked = locked.minus(release);

      const existing = await tx.holding.findUnique({ where: { portfolioId_symbol: { portfolioId: portfolio.id, symbol: order.symbol } } });
      if (existing) {
        const newQty = existing.quantity + q;
        // Average cost includes fees (true break-even price).
        const avg = r4(existing.averageBuyPrice.times(existing.quantity).plus(total).div(newQty));
        await tx.holding.update({ where: { id: existing.id }, data: { quantity: newQty, averageBuyPrice: avg } });
      } else {
        await tx.holding.create({
          data: { portfolioId: portfolio.id, symbol: order.symbol, quantity: q, averageBuyPrice: r4(total.div(q)) },
        });
      }
      await tx.ledgerEntry.createMany({
        data: [
          { portfolioId: portfolio.id, type: 'BUY_SETTLEMENT', cashDelta: cost.neg(), buyingPowerDelta: release.minus(cost), cashBalanceAfter: portfolio.cashBalance.plus(fee), refId: order.id },
          { portfolioId: portfolio.id, type: 'FEE', cashDelta: fee.neg(), buyingPowerDelta: fee.neg(), cashBalanceAfter: portfolio.cashBalance, refId: order.id },
        ],
      });
    } else {
      const proceeds = cost.minus(fee);
      const holding = await tx.holding.findUniqueOrThrow({ where: { portfolioId_symbol: { portfolioId: portfolio.id, symbol: order.symbol } } });
      const newQty = holding.quantity - q;
      if (newQty === 0) {
        await tx.holding.delete({ where: { id: holding.id } });
      } else {
        await tx.holding.update({ where: { id: holding.id }, data: { quantity: newQty, reservedQuantity: { decrement: q } } });
      }
      portfolio = await tx.portfolio.update({
        where: { id: portfolio.id },
        data: { cashBalance: { increment: proceeds }, buyingPower: { increment: proceeds } },
      });
      await tx.ledgerEntry.createMany({
        data: [
          { portfolioId: portfolio.id, type: 'SELL_SETTLEMENT', cashDelta: cost, buyingPowerDelta: cost, cashBalanceAfter: portfolio.cashBalance.plus(fee), refId: order.id },
          { portfolioId: portfolio.id, type: 'FEE', cashDelta: fee.neg(), buyingPowerDelta: fee.neg(), cashBalanceAfter: portfolio.cashBalance, refId: order.id },
        ],
      });
    }

    trades.push(
      await tx.trade.create({
        data: { orderId: order.id, userId: order.userId, symbol: order.symbol, side: order.side, quantity: q, price: f.price, fee },
      }),
    );
    applied.push({ price: f.price, quantity: q });
    filled += q;
    remaining -= q;
    notional = notional.plus(f.price.times(q));
  }

  if (applied.length === 0) return { order, trades, applied, unaffordable: false };

  // Fully filled BUY: hand back any rounding residue of the reservation.
  if (remaining === 0 && order.side === 'BUY' && locked.gt(0)) {
    await tx.portfolio.update({ where: { id: portfolio.id }, data: { buyingPower: { increment: locked } } });
    locked = ZERO;
  }

  const updated = await tx.order.update({
    where: { id: order.id },
    data: {
      filledQuantity: filled,
      lockedAmount: locked,
      averageFillPrice: r4(notional.div(filled)),
      status: remaining === 0 ? 'EXECUTED' : 'PARTIALLY_FILLED',
    },
  });
  return { order: updated, trades, applied, unaffordable: false };
}

/** Cancel the unfilled remainder and release its reservation. Caller MUST hold the order lock. */
export async function cancelRemainder(tx: Tx, order: Order, reason: string): Promise<Order> {
  const remaining = remainingOf(order);
  await lockPortfolio(tx, order.portfolioId);
  if (order.side === 'BUY') {
    if (order.lockedAmount.gt(0)) {
      await tx.portfolio.update({ where: { id: order.portfolioId }, data: { buyingPower: { increment: order.lockedAmount } } });
    }
  } else if (remaining > 0) {
    await tx.holding.update({
      where: { portfolioId_symbol: { portfolioId: order.portfolioId, symbol: order.symbol } },
      data: { reservedQuantity: { decrement: remaining } },
    });
  }
  return tx.order.update({
    where: { id: order.id },
    data: { status: 'CANCELLED', lockedAmount: ZERO, cancelReason: reason.slice(0, 200) },
  });
}

function minDec(a: Dec, b: Dec): Dec {
  return a.lt(b) ? a : b;
}
