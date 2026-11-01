import { Router } from 'express';
import type { Prisma, Stock } from '@prisma/client';
import { CurrencyEnum, ErrorResponse, registry, z } from '../../docs/registry';
import { NotFound } from '../../lib/errors';
import { D, pctChange, toStr } from '../../lib/money';
import { prisma } from '../../lib/prisma';
import { getBook, getQuotes, getRecentTrades } from '../../market/quotes';
import { priceBand } from '../../market/rules';
import { marketStatus } from '../../market/session';
import type { TickPayload } from '../../realtime/events';
import { validate } from '../../middleware/validate';

export const stocksRouter = Router();

const bool = z.enum(['true', 'false']).transform((v) => v === 'true');

const ListQuery = z.object({
  sector: z.string().trim().max(120).optional().openapi({ description: 'English or Arabic sector name', example: 'Banks' }),
  q: z.string().trim().max(60).optional().openapi({ description: 'Search symbol or name (EN/AR)' }),
  sharia: bool.optional(),
  currency: CurrencyEnum.optional(),
  sort: z.enum(['symbol', 'changePct', 'volume', 'price']).default('symbol'),
  order: z.enum(['asc', 'desc']).default('asc'),
});
const SymbolParams = z.object({ symbol: z.string().trim().toUpperCase().regex(/^[A-Z0-9.]{1,16}$/) });

function quoteView(s: Stock, live?: TickPayload) {
  const price = live ? D(live.price) : s.currentPrice;
  const prev = live ? D(live.previousClose) : s.previousClose;
  return {
    symbol: s.symbol,
    nameAr: s.nameAr,
    nameEn: s.nameEn,
    sectorAr: s.sectorAr,
    sectorEn: s.sectorEn,
    currency: s.currency,
    isShariaCompliant: s.isShariaCompliant,
    price: price.toFixed(),
    previousClose: prev.toFixed(),
    change: price.minus(prev).toFixed(4),
    changePct: pctChange(price, prev),
    volume: live?.volume ?? s.volume.toString(),
    bid: live?.bid ?? null,
    ask: live?.ask ?? null,
    updatedAt: live ? new Date(live.ts).toISOString() : s.updatedAt.toISOString(),
  };
}

stocksRouter.get('/', validate({ query: ListQuery }), async (req, res) => {
  const q = req.valid.query as z.infer<typeof ListQuery>;
  const where: Prisma.StockWhereInput = {
    isActive: true,
    currency: q.currency,
    isShariaCompliant: q.sharia,
    ...(q.sector && { OR: [{ sectorEn: { equals: q.sector, mode: 'insensitive' } }, { sectorAr: q.sector }] }),
    ...(q.q && {
      AND: [
        {
          OR: [
            { symbol: { contains: q.q, mode: 'insensitive' } },
            { nameEn: { contains: q.q, mode: 'insensitive' } },
            { nameAr: { contains: q.q } },
          ],
        },
      ],
    }),
  };
  const stocks = await prisma.stock.findMany({ where, orderBy: { symbol: 'asc' } });
  const live = await getQuotes(stocks.map((s) => s.symbol));
  const items = stocks.map((s) => quoteView(s, live.get(s.symbol)));

  const dir = q.order === 'asc' ? 1 : -1;
  const key: Record<typeof q.sort, (x: (typeof items)[number]) => number | string> = {
    symbol: (x) => x.symbol,
    changePct: (x) => x.changePct,
    volume: (x) => Number(x.volume),
    price: (x) => Number(x.price),
  };
  items.sort((a, b) => (key[q.sort](a) > key[q.sort](b) ? dir : key[q.sort](a) < key[q.sort](b) ? -dir : 0));
  res.json({ items, market: marketStatus() });
});

stocksRouter.get('/sectors', async (_req, res) => {
  const rows = await prisma.stock.groupBy({ by: ['sectorEn', 'sectorAr'], where: { isActive: true }, _count: { _all: true } });
  res.json(rows.map((r) => ({ sectorEn: r.sectorEn, sectorAr: r.sectorAr, count: r._count._all })).sort((a, b) => a.sectorEn.localeCompare(b.sectorEn)));
});

stocksRouter.get('/:symbol', validate({ params: SymbolParams }), async (req, res) => {
  const stock = await prisma.stock.findUnique({ where: { symbol: req.valid.params.symbol } });
  if (!stock || !stock.isActive) throw NotFound('Stock');
  const live = (await getQuotes([stock.symbol])).get(stock.symbol);
  const prev = live ? D(live.previousClose) : stock.previousClose;
  const price = live ? D(live.price) : stock.currentPrice;
  const high = live ? D(live.high) : stock.dayHigh;
  const low = live ? D(live.low) : stock.dayLow;
  const band = priceBand(prev);
  res.json({
    ...quoteView(stock, live),
    open: live?.open ?? stock.openPrice.toFixed(),
    dayHigh: high.toFixed(),
    dayLow: low.toFixed(),
    peRatio: toStr(stock.peRatio),
    week52High: toStr(stock.week52High && (high.gt(stock.week52High) ? high : stock.week52High)),
    week52Low: toStr(stock.week52Low && (low.lt(stock.week52Low) ? low : stock.week52Low)),
    priceLimits: { min: band.min.toFixed(4), max: band.max.toFixed(4) },
    lastPrice: price.toFixed(),
    market: marketStatus(),
  });
});

stocksRouter.get('/:symbol/depth', validate({ params: SymbolParams }), async (req, res) => {
  const symbol = req.valid.params.symbol as string;
  const exists = await prisma.stock.count({ where: { symbol, isActive: true } });
  if (!exists) throw NotFound('Stock');
  const [book, trades] = await Promise.all([getBook(symbol), getRecentTrades(symbol, 30)]);
  const bids = book?.bids ?? [];
  const asks = book?.asks ?? [];
  const spread = bids[0] && asks[0] ? D(asks[0].price).minus(D(bids[0].price)).toFixed(4) : null;
  res.json({
    symbol,
    bids,
    asks,
    spread,
    totalBidQuantity: bids.reduce((s, l) => s + l.quantity, 0),
    totalAskQuantity: asks.reduce((s, l) => s + l.quantity, 0),
    recentTrades: trades.map((t) => ({ ...t, time: new Date(t.ts).toISOString() })),
    ts: book?.ts ?? Date.now(),
  });
});

// ---- OpenAPI ----
const json = <T extends z.ZodTypeAny>(schema: T) => ({ content: { 'application/json': { schema } } });
const Quote = z
  .object({
    symbol: z.string(), nameAr: z.string(), nameEn: z.string(), sectorAr: z.string(), sectorEn: z.string(),
    currency: CurrencyEnum, isShariaCompliant: z.boolean(),
    price: z.string(), previousClose: z.string(), change: z.string(), changePct: z.number(),
    volume: z.string(), bid: z.string().nullable(), ask: z.string().nullable(), updatedAt: z.string(),
  })
  .openapi('StockQuote');
const Level = z.object({ price: z.string(), quantity: z.number(), orders: z.number() }).openapi('BookLevel');

registry.registerPath({
  method: 'get', path: '/api/v1/stocks', tags: ['Stocks'], summary: 'All stocks with live price, change % and volume',
  request: { query: ListQuery },
  responses: { 200: { description: 'OK', ...json(z.object({ items: z.array(Quote), market: z.any() })) } },
});
registry.registerPath({
  method: 'get', path: '/api/v1/stocks/sectors', tags: ['Stocks'], summary: 'Sector list for filters',
  responses: { 200: { description: 'OK', ...json(z.array(z.object({ sectorEn: z.string(), sectorAr: z.string(), count: z.number() }))) } },
});
registry.registerPath({
  method: 'get', path: '/api/v1/stocks/{symbol}', tags: ['Stocks'], summary: 'Stock statistics (open/high/low, P/E, 52-week range, price limits)',
  request: { params: SymbolParams },
  responses: {
    200: {
      description: 'OK',
      ...json(Quote.extend({
        open: z.string(), dayHigh: z.string(), dayLow: z.string(), peRatio: z.string().nullable(),
        week52High: z.string().nullable(), week52Low: z.string().nullable(),
        priceLimits: z.object({ min: z.string(), max: z.string() }), lastPrice: z.string(), market: z.any(),
      })),
    },
    404: { description: 'Unknown symbol', ...json(ErrorResponse) },
  },
});
registry.registerPath({
  method: 'get', path: '/api/v1/stocks/{symbol}/depth', tags: ['Stocks'], summary: 'Level 2 order book and recent trades',
  request: { params: SymbolParams },
  responses: {
    200: {
      description: 'OK',
      ...json(z.object({
        symbol: z.string(), bids: z.array(Level), asks: z.array(Level), spread: z.string().nullable(),
        totalBidQuantity: z.number(), totalAskQuantity: z.number(),
        recentTrades: z.array(z.object({ price: z.string(), quantity: z.number(), side: z.enum(['BUY', 'SELL']), time: z.string() })),
        ts: z.number(),
      })),
    },
    404: { description: 'Unknown symbol', ...json(ErrorResponse) },
  },
});
