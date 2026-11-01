import { Router } from 'express';
import { CurrencyEnum, commonErrors, registry, secured, z } from '../../docs/registry';
import { D, pctChange, r2, ZERO } from '../../lib/money';
import { prisma } from '../../lib/prisma';
import { getQuotes } from '../../market/quotes';
import { requireAuth } from '../../middleware/auth';

export const portfolioRouter = Router();
portfolioRouter.use(requireAuth);

portfolioRouter.get('/summary', async (req, res) => {
  const portfolios = await prisma.portfolio.findMany({
    where: { userId: req.user!.id },
    include: { holdings: { include: { stock: true }, orderBy: { symbol: 'asc' } } },
    orderBy: { currency: 'asc' },
  });
  const symbols = [...new Set(portfolios.flatMap((p) => p.holdings.map((h) => h.symbol)))];
  const live = await getQuotes(symbols);

  const wallets = portfolios.map((p) => {
    let marketValue = ZERO;
    let costBasis = ZERO;
    let dayChange = ZERO;
    const holdings = p.holdings.map((h) => {
      const q = live.get(h.symbol);
      const price = q ? D(q.price) : h.stock.currentPrice;
      const prev = q ? D(q.previousClose) : h.stock.previousClose;
      const value = price.times(h.quantity);
      const cost = h.averageBuyPrice.times(h.quantity);
      marketValue = marketValue.plus(value);
      costBasis = costBasis.plus(cost);
      dayChange = dayChange.plus(price.minus(prev).times(h.quantity));
      return {
        symbol: h.symbol,
        nameEn: h.stock.nameEn,
        nameAr: h.stock.nameAr,
        quantity: h.quantity,
        reservedQuantity: h.reservedQuantity,
        availableQuantity: h.quantity - h.reservedQuantity,
        averageBuyPrice: h.averageBuyPrice.toFixed(4),
        currentPrice: price.toFixed(),
        marketValue: r2(value).toFixed(2),
        unrealizedPnl: r2(value.minus(cost)).toFixed(2),
        unrealizedPnlPct: pctChange(value, cost),
        dayChange: r2(price.minus(prev).times(h.quantity)).toFixed(2),
        dayChangePct: pctChange(price, prev),
      };
    });
    const locked = p.cashBalance.minus(p.buyingPower);
    return {
      currency: p.currency,
      cashBalance: r2(p.cashBalance).toFixed(2),
      buyingPower: r2(p.buyingPower).toFixed(2),
      lockedAmount: r2(locked).toFixed(2),
      holdingsValue: r2(marketValue).toFixed(2),
      totalEquity: r2(p.cashBalance.plus(marketValue)).toFixed(2),
      unrealizedPnl: r2(marketValue.minus(costBasis)).toFixed(2),
      unrealizedPnlPct: pctChange(marketValue, costBasis),
      dayChange: r2(dayChange).toFixed(2),
      holdings,
    };
  });

  res.json({ userId: req.user!.id, unifiedId: req.user!.unifiedId, wallets, asOf: new Date().toISOString() });
});

const Holding = z
  .object({
    symbol: z.string(), nameEn: z.string(), nameAr: z.string(), quantity: z.number(), reservedQuantity: z.number(),
    availableQuantity: z.number(), averageBuyPrice: z.string(), currentPrice: z.string(), marketValue: z.string(),
    unrealizedPnl: z.string(), unrealizedPnlPct: z.number(), dayChange: z.string(), dayChangePct: z.number(),
  })
  .openapi('Holding');
const Wallet = z
  .object({
    currency: CurrencyEnum, cashBalance: z.string(), buyingPower: z.string(), lockedAmount: z.string(),
    holdingsValue: z.string(), totalEquity: z.string(), unrealizedPnl: z.string(), unrealizedPnlPct: z.number(),
    dayChange: z.string(), holdings: z.array(Holding),
  })
  .openapi('WalletSummary');

registry.registerPath({
  method: 'get', path: '/api/v1/portfolio/summary', tags: ['Portfolio'], security: secured,
  summary: 'Cash, buying power, holdings valuation and P/L for the EGP and USD wallets',
  responses: {
    200: { description: 'OK', content: { 'application/json': { schema: z.object({ userId: z.string(), unifiedId: z.string(), wallets: z.array(Wallet), asOf: z.string() }) } } },
    ...commonErrors,
  },
});
