import request from 'supertest';
import { expect } from 'vitest';
import type { Currency } from '@prisma/client';
import { createApp } from '../src/app';
import { prisma } from '../src/lib/prisma';
import { redis } from '../src/lib/redis';

export const app = createApp();

let seq = 0;
export const uniqueEmail = (p = 'user') => `${p}.${Date.now()}.${++seq}@test.amalka.app`;

export async function resetDb(): Promise<void> {
  await prisma.$executeRawUnsafe(
    'TRUNCATE "trades", "ledger_entries", "orders", "holdings", "price_alerts", "payment_events", "transfers", "refresh_tokens", "portfolios", "users", "stocks" CASCADE',
  );
  await redis.flushdb();
  await prisma.stock.createMany({
    data: [
      { symbol: 'COMI', nameEn: 'Commercial International Bank', nameAr: 'البنك التجاري الدولي', sectorEn: 'Banks', sectorAr: 'البنوك', currentPrice: '80', previousClose: '80', openPrice: '80', dayHigh: '80', dayLow: '80', volume: 0n, isShariaCompliant: false, currency: 'EGP', peRatio: '6.1', week52High: '100', week52Low: '55' },
      { symbol: 'TMGH', nameEn: 'Talaat Moustafa Group', nameAr: 'مجموعة طلعت مصطفى', sectorEn: 'Real Estate', sectorAr: 'العقارات', currentPrice: '50', previousClose: '50', openPrice: '50', dayHigh: '50', dayLow: '50', volume: 0n, isShariaCompliant: true, currency: 'EGP' },
      { symbol: 'EKHO', nameEn: 'Egypt Kuwait Holding', nameAr: 'القابضة المصرية الكويتية', sectorEn: 'Financials', sectorAr: 'الخدمات المالية', currentPrice: '1.000', previousClose: '1.000', openPrice: '1', dayHigh: '1', dayLow: '1', volume: 0n, isShariaCompliant: false, currency: 'USD' },
    ],
  });
}

export interface TestUser {
  id: string;
  email: string;
  password: string;
  accessToken: string;
  refreshToken: string;
  auth: { Authorization: string };
}

export async function registerUser(prefix = 'user'): Promise<TestUser> {
  const email = uniqueEmail(prefix);
  const password = 'Passw0rd!';
  const res = await request(app)
    .post('/api/v1/auth/register')
    .send({ email, password, fullNameAr: 'مستخدم اختبار', fullNameEn: 'Test User' });
  expect(res.status).toBe(201);
  return {
    id: res.body.user.id,
    email,
    password,
    accessToken: res.body.accessToken,
    refreshToken: res.body.refreshToken,
    auth: { Authorization: `Bearer ${res.body.accessToken}` },
  };
}

/** Credit a wallet the same way a completed deposit would (with a ledger entry). */
export async function fund(userId: string, currency: Currency, amount: string): Promise<void> {
  const p = await prisma.portfolio.findUniqueOrThrow({ where: { userId_currency: { userId, currency } } });
  const t = await prisma.transfer.create({
    data: { userId, portfolioId: p.id, amount, currency, type: 'DEPOSIT', method: 'Bank Transfer', provider: 'MANUAL', status: 'COMPLETED' },
  });
  const w = await prisma.portfolio.update({ where: { id: p.id }, data: { cashBalance: { increment: amount }, buyingPower: { increment: amount } } });
  await prisma.ledgerEntry.create({ data: { portfolioId: p.id, type: 'DEPOSIT', cashDelta: amount, buyingPowerDelta: amount, cashBalanceAfter: w.cashBalance, refId: t.id } });
}

export async function giveShares(userId: string, symbol: string, quantity: number, avg = '70'): Promise<void> {
  const stock = await prisma.stock.findUniqueOrThrow({ where: { symbol } });
  const p = await prisma.portfolio.findUniqueOrThrow({ where: { userId_currency: { userId, currency: stock.currency } } });
  await prisma.holding.create({ data: { portfolioId: p.id, symbol, quantity, averageBuyPrice: avg } });
}

export async function wallet(userId: string, currency: Currency = 'EGP') {
  return prisma.portfolio.findUniqueOrThrow({ where: { userId_currency: { userId, currency } } });
}

/**
 * The accounting invariants every test ends with:
 *  1. reserved cash (cash − buying power) == Σ locked_amount of open BUY orders + Σ pending withdrawals
 *  2. cash balance == Σ ledger cash deltas (every cash movement is journaled)
 *  3. reserved shares == Σ remaining quantity of open SELL orders
 */
export async function assertBooksBalance(): Promise<void> {
  const rows = await prisma.$queryRaw<{ id: string; reserved: string; expected: string; cash: string; ledger: string }[]>`
    SELECT p.id::text,
           (p.cash_balance - p.buying_power)::text AS reserved,
           (COALESCE((SELECT SUM(o.locked_amount) FROM orders o WHERE o.portfolio_id = p.id AND o.status IN ('PENDING','PARTIALLY_FILLED')), 0)
          + COALESCE((SELECT SUM(t.amount) FROM transfers t WHERE t.portfolio_id = p.id AND t.type = 'WITHDRAWAL' AND t.status = 'PENDING'), 0))::text AS expected,
           p.cash_balance::text AS cash,
           COALESCE((SELECT SUM(l.cash_delta) FROM ledger_entries l WHERE l.portfolio_id = p.id), 0)::text AS ledger
      FROM portfolios p`;
  for (const r of rows) {
    expect(Number(r.reserved), `reserved cash of portfolio ${r.id}`).toBeCloseTo(Number(r.expected), 4);
    expect(Number(r.cash), `ledger of portfolio ${r.id}`).toBeCloseTo(Number(r.ledger), 4);
    expect(Number(r.reserved)).toBeGreaterThanOrEqual(0);
  }
  const shares = await prisma.$queryRaw<{ id: string; reserved: number; expected: number }[]>`
    SELECT h.id::text, h.reserved_quantity AS reserved,
           COALESCE((SELECT SUM(o.quantity - o.filled_quantity) FROM orders o
                      WHERE o.portfolio_id = h.portfolio_id AND o.symbol = h.symbol AND o.side = 'SELL'
                        AND o.status IN ('PENDING','PARTIALLY_FILLED')), 0)::int AS expected
      FROM holdings h`;
  for (const s of shares) expect(s.reserved, `reserved shares of holding ${s.id}`).toBe(s.expected);
}
