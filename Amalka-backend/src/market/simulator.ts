import type { OrderSide } from '@prisma/client';
import { env } from '../config/env';
import { logger } from '../lib/logger';
import { pctChange, type Dec } from '../lib/money';
import { prisma } from '../lib/prisma';
import { redis } from '../lib/redis';
import { CHANNELS, publish, type TickPayload } from '../realtime/events';
import { MD_KEYS, recordPrint, type CachedBook } from './quotes';
import { roundToTick, tickSize } from './rules';
import { isMarketOpen, todayLocal } from './session';
import { depleteBook, walkBook, type Book, type ExecutionVenue, type Fill } from './venue';

interface SymState {
  symbol: string;
  price: Dec;
  previousClose: Dec;
  open: Dec;
  high: Dec;
  low: Dec;
  volume: bigint;
  book: Book;
  dirty: boolean;
}

function gaussian(): number {
  let u = 0;
  let v = 0;
  while (u === 0) u = Math.random();
  while (v === 0) v = Math.random();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}

const rand = (min: number, max: number) => Math.floor(min + Math.random() * (max - min + 1));

/**
 * Random-walk market simulator: moves prices within the daily price band,
 * maintains a synthetic Level-2 book per symbol and acts as the execution venue.
 * Replace with a licensed market-data feed + broker connection for production.
 */
export class MarketSimulator implements ExecutionVenue {
  private state = new Map<string, SymState>();
  private timer?: NodeJS.Timeout;
  private persistTimer?: NodeJS.Timeout;
  private sessionDate = todayLocal();
  private listeners: ((ticks: TickPayload[]) => Promise<void> | void)[] = [];

  onTick(fn: (ticks: TickPayload[]) => Promise<void> | void): void {
    this.listeners.push(fn);
  }

  async start(): Promise<void> {
    await this.load();
    this.timer = setInterval(() => void this.tick().catch((e) => logger.error({ err: e }, 'simulator tick failed')), env.MARKET_TICK_MS);
    this.persistTimer = setInterval(() => void this.persist().catch((e) => logger.error({ err: e }, 'simulator persist failed')), 5_000);
    logger.info({ symbols: this.state.size, tickMs: env.MARKET_TICK_MS }, 'market simulator started');
  }

  async stop(): Promise<void> {
    if (this.timer) clearInterval(this.timer);
    if (this.persistTimer) clearInterval(this.persistTimer);
    await this.persist().catch(() => undefined);
  }

  private async load(): Promise<void> {
    const stocks = await prisma.stock.findMany({ where: { isActive: true } });
    for (const s of stocks) {
      const st: SymState = {
        symbol: s.symbol,
        price: s.currentPrice,
        previousClose: s.previousClose,
        open: s.openPrice,
        high: s.dayHigh,
        low: s.dayLow,
        volume: s.volume,
        book: { bids: [], asks: [] },
        dirty: false,
      };
      st.book = this.buildBook(st.price);
      this.state.set(s.symbol, st);
    }
    // Publish an initial snapshot so the API has quotes immediately.
    await this.cache([...this.state.values()]);
  }

  private buildBook(mid: Dec): Book {
    const t = tickSize(mid);
    const spreadTicks = rand(1, 3);
    const bestBid = roundToTick(mid.minus(t.times(Math.ceil(spreadTicks / 2))));
    const bestAsk = roundToTick(mid.plus(t.times(Math.max(1, Math.floor(spreadTicks / 2)))));
    // Lower-priced shares trade in larger size.
    const baseQty = Math.max(50, Math.round(200_000 / Math.max(1, Number(mid))));
    const bids = [];
    const asks = [];
    for (let i = 0; i < 10; i++) {
      const bidPx = bestBid.minus(t.times(i));
      if (bidPx.gt(0)) bids.push({ price: bidPx, quantity: rand(baseQty / 4, baseQty * 2), orders: rand(1, 25) });
      asks.push({ price: bestAsk.plus(t.times(i)), quantity: rand(baseQty / 4, baseQty * 2), orders: rand(1, 25) });
    }
    return { bids, asks };
  }

  private rollSessionIfNeeded(): void {
    const today = todayLocal();
    if (today === this.sessionDate || !isMarketOpen()) return;
    this.sessionDate = today;
    for (const st of this.state.values()) {
      st.previousClose = st.price;
      st.open = st.price;
      st.high = st.price;
      st.low = st.price;
      st.volume = 0n;
      st.dirty = true;
    }
    logger.info({ session: today }, 'new trading session — day stats reset');
  }

  private async tick(): Promise<void> {
    if (env.ENFORCE_MARKET_HOURS && !isMarketOpen()) return;
    this.rollSessionIfNeeded();

    const band = env.PRICE_BAND_PCT * 0.95;
    const changed: SymState[] = [];
    for (const st of this.state.values()) {
      if (Math.random() < 0.35) continue; // not every stock trades every tick
      const drift = gaussian() * 0.0025;
      const upper = st.previousClose.times(1 + band);
      const lower = st.previousClose.times(1 - band);
      let next = roundToTick(st.price.times(1 + drift));
      if (next.gt(upper)) next = roundToTick(upper);
      if (next.lt(lower)) next = roundToTick(lower);
      if (next.lte(0)) next = tickSize(st.price);

      const prints = rand(1, 3);
      for (let i = 0; i < prints; i++) {
        const qty = rand(10, Math.max(20, Math.round(50_000 / Math.max(1, Number(next)))));
        st.volume += BigInt(qty);
        await recordPrint(st.symbol, { price: next.toFixed(), quantity: qty, side: Math.random() < 0.5 ? 'BUY' : 'SELL', ts: Date.now() }).catch(() => undefined);
      }
      st.price = next;
      if (next.gt(st.high)) st.high = next;
      if (next.lt(st.low)) st.low = next;
      st.book = this.buildBook(next);
      st.dirty = true;
      changed.push(st);
    }
    if (changed.length === 0) return;

    const ticks = await this.cache(changed);
    await publish(CHANNELS.ticks, { type: 'tick', data: ticks });
    for (const l of this.listeners) await l(ticks);
  }

  private toTick(st: SymState): TickPayload {
    return {
      symbol: st.symbol,
      price: st.price.toFixed(),
      previousClose: st.previousClose.toFixed(),
      change: st.price.minus(st.previousClose).toFixed(4),
      changePct: pctChange(st.price, st.previousClose),
      open: st.open.toFixed(),
      high: st.high.toFixed(),
      low: st.low.toFixed(),
      volume: st.volume.toString(),
      bid: st.book.bids[0]?.price.toFixed() ?? null,
      ask: st.book.asks[0]?.price.toFixed() ?? null,
      ts: Date.now(),
    };
  }

  private async cache(states: SymState[]): Promise<TickPayload[]> {
    const ticks = states.map((s) => this.toTick(s));
    const pipe = redis.pipeline();
    for (const [i, st] of states.entries()) {
      pipe.hset(MD_KEYS.quotes, st.symbol, JSON.stringify(ticks[i]));
      const book: CachedBook = {
        bids: st.book.bids.map((l) => ({ price: l.price.toFixed(), quantity: l.quantity, orders: l.orders })),
        asks: st.book.asks.map((l) => ({ price: l.price.toFixed(), quantity: l.quantity, orders: l.orders })),
        ts: Date.now(),
      };
      pipe.set(MD_KEYS.book(st.symbol), JSON.stringify(book), 'EX', 120);
    }
    await pipe.exec().catch((e) => logger.warn({ err: (e as Error).message }, 'quote cache write failed'));
    return ticks;
  }

  /** Persist latest prices to Postgres (throttled; Redis is the hot path). */
  private async persist(): Promise<void> {
    const dirty = [...this.state.values()].filter((s) => s.dirty);
    if (dirty.length === 0) return;
    for (const s of dirty) s.dirty = false;
    await prisma.$transaction(
      dirty.map((s) =>
        prisma.stock.update({
          where: { symbol: s.symbol },
          data: {
            currentPrice: s.price,
            previousClose: s.previousClose,
            openPrice: s.open,
            dayHigh: s.high,
            dayLow: s.low,
            volume: s.volume,
          },
        }),
      ),
    );
  }

  // ---- ExecutionVenue ----
  book(symbol: string): Book | null {
    return this.state.get(symbol)?.book ?? null;
  }

  peek(symbol: string, side: OrderSide, limit: Dec | null, maxQty: number): Fill[] {
    return walkBook(this.book(symbol), side, limit, maxQty);
  }

  consume(symbol: string, side: OrderSide, fills: Fill[]): void {
    const st = this.state.get(symbol);
    if (!st) return;
    depleteBook(st.book, side, fills);
    for (const f of fills) st.volume += BigInt(f.quantity);
    st.dirty = true;
    void this.cache([st]);
  }
}
