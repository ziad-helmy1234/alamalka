import type { OrderSide } from '@prisma/client';
import { D, type Dec } from '../lib/money';

export interface BookLevel {
  price: Dec;
  quantity: number;
  orders: number;
}

/** bids sorted best (highest) first, asks sorted best (lowest) first */
export interface Book {
  bids: BookLevel[];
  asks: BookLevel[];
}

export interface Fill {
  price: Dec;
  quantity: number;
}

/**
 * Where orders get executed. The bundled implementation is a market simulator;
 * in production this is replaced by a licensed EGX broker's order-routing API
 * (FIX / REST), whose execution reports feed the same settlement functions.
 */
export interface ExecutionVenue {
  /** Liquidity an order could take right now (best prices first), without consuming it. */
  peek(symbol: string, side: OrderSide, limit: Dec | null, maxQty: number): Fill[];
  /** Remove liquidity that was actually executed. */
  consume(symbol: string, side: OrderSide, fills: Fill[]): void;
  book(symbol: string): Book | null;
}

/** Walk the opposite side of the book within the limit price. */
export function walkBook(book: Book | null, side: OrderSide, limit: Dec | null, maxQty: number): Fill[] {
  if (!book || maxQty <= 0) return [];
  const levels = side === 'BUY' ? book.asks : book.bids;
  const fills: Fill[] = [];
  let left = maxQty;
  for (const lvl of levels) {
    if (left <= 0) break;
    if (limit) {
      if (side === 'BUY' && lvl.price.gt(limit)) break;
      if (side === 'SELL' && lvl.price.lt(limit)) break;
    }
    const q = Math.min(left, lvl.quantity);
    if (q > 0) {
      fills.push({ price: lvl.price, quantity: q });
      left -= q;
    }
  }
  return fills;
}

export function depleteBook(book: Book | null, side: OrderSide, fills: Fill[]): void {
  if (!book) return;
  const levels = side === 'BUY' ? book.asks : book.bids;
  for (const f of fills) {
    const lvl = levels.find((l) => l.price.eq(f.price));
    if (lvl) lvl.quantity = Math.max(0, lvl.quantity - f.quantity);
  }
  const keep = levels.filter((l) => l.quantity > 0);
  if (side === 'BUY') book.asks = keep;
  else book.bids = keep;
}

/** Deterministic venue with a fixed book — used by tests and for manual QA. */
export class StaticBookVenue implements ExecutionVenue {
  private books = new Map<string, Book>();

  setBook(symbol: string, bids: [number | string, number][], asks: [number | string, number][]): void {
    const mk = (l: [number | string, number]) => ({ price: D(l[0]), quantity: l[1], orders: 1 });
    this.books.set(symbol, {
      bids: bids.map(mk).sort((a, b) => b.price.comparedTo(a.price)),
      asks: asks.map(mk).sort((a, b) => a.price.comparedTo(b.price)),
    });
  }

  clear(): void {
    this.books.clear();
  }

  book(symbol: string): Book | null {
    return this.books.get(symbol) ?? null;
  }

  peek(symbol: string, side: OrderSide, limit: Dec | null, maxQty: number): Fill[] {
    return walkBook(this.book(symbol), side, limit, maxQty);
  }

  consume(symbol: string, side: OrderSide, fills: Fill[]): void {
    depleteBook(this.book(symbol), side, fills);
  }
}
