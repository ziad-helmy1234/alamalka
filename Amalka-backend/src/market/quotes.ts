import { redis } from '../lib/redis';
import type { TickPayload } from '../realtime/events';

/** Redis keys for the live market-data cache shared by all instances. */
export const MD_KEYS = {
  quotes: 'md:quotes',
  book: (symbol: string) => `md:book:${symbol}`,
  trades: (symbol: string) => `md:trades:${symbol}`,
} as const;

export interface CachedBook {
  bids: { price: string; quantity: number; orders: number }[];
  asks: { price: string; quantity: number; orders: number }[];
  ts: number;
}

export interface CachedTrade {
  price: string;
  quantity: number;
  side: 'BUY' | 'SELL';
  ts: number;
}

export async function getQuotes(symbols: string[]): Promise<Map<string, TickPayload>> {
  const out = new Map<string, TickPayload>();
  if (symbols.length === 0) return out;
  try {
    const values = await redis.hmget(MD_KEYS.quotes, ...symbols);
    values.forEach((v, i) => {
      if (v) out.set(symbols[i], JSON.parse(v) as TickPayload);
    });
  } catch {
    // cache miss → callers fall back to DB values
  }
  return out;
}

export async function getBook(symbol: string): Promise<CachedBook | null> {
  const v = await redis.get(MD_KEYS.book(symbol)).catch(() => null);
  return v ? (JSON.parse(v) as CachedBook) : null;
}

export async function getRecentTrades(symbol: string, limit = 30): Promise<CachedTrade[]> {
  const list = await redis.lrange(MD_KEYS.trades(symbol), 0, limit - 1).catch(() => [] as string[]);
  return list.map((v) => JSON.parse(v) as CachedTrade);
}

export async function recordPrint(symbol: string, trade: CachedTrade): Promise<void> {
  await redis.multi().lpush(MD_KEYS.trades(symbol), JSON.stringify(trade)).ltrim(MD_KEYS.trades(symbol), 0, 99).exec();
}
