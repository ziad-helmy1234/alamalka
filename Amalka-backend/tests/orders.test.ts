import request from 'supertest';
import { beforeEach, describe, expect, it } from 'vitest';
import { expireOrders } from '../src/jobs/expiry';
import { prisma } from '../src/lib/prisma';
import { StaticBookVenue } from '../src/market/venue';
import { engine } from '../src/oms/engine';
import { app, assertBooksBalance, fund, giveShares, registerUser, resetDb, wallet, type TestUser } from './helpers';

const venue = new StaticBookVenue();
const custodianBank = 'CIB Custody';

let u: TestUser;
beforeEach(async () => {
  await resetDb();
  venue.clear();
  engine.setVenue(venue);
  u = await registerUser();
});

const place = (user: TestUser, body: Record<string, unknown>, headers: Record<string, string> = {}) =>
  request(app).post('/api/v1/orders').set(user.auth).set(headers).send({ custodianBank, ...body });

const tick = (symbol: string, bid: string | null, ask: string | null) =>
  engine.onTicks([{ symbol, price: ask ?? bid ?? '0', previousClose: '80', change: '0', changePct: 0, open: '80', high: '80', low: '80', volume: '0', bid, ask, ts: Date.now() }]);

describe('order placement & buying power', () => {
  it('locks price × qty × (1+fee) for a BUY LIMIT order and rests it when not marketable', async () => {
    await fund(u.id, 'EGP', '10000');
    const res = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 100 });
    expect(res.status).toBe(201);
    expect(res.body.id).toMatch(/^ORD-\d+$/);
    expect(res.body.status).toBe('PENDING');
    expect(res.body.lockedAmount).toBe('8016.0000'); // 80 × 100 × 1.002
    const w = await wallet(u.id);
    expect(w.cashBalance.toFixed(2)).toBe('10000.00');
    expect(w.buyingPower.toFixed(2)).toBe('1984.00');
    await assertBooksBalance();
  });

  it('rejects orders exceeding buying power without side effects', async () => {
    await fund(u.id, 'EGP', '1000');
    const res = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 100 });
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('INSUFFICIENT_BUYING_POWER');
    expect(await prisma.order.count()).toBe(0);
    expect((await wallet(u.id)).buyingPower.toFixed(2)).toBe('1000.00');
  });

  it('validates EGX price rules, custodian and order combinations', async () => {
    await fund(u.id, 'EGP', '100000');
    const cases: [Record<string, unknown>, number, string][] = [
      [{ symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '100', quantity: 1 }, 422, 'PRICE_OUT_OF_BAND'],
      [{ symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80.005', quantity: 1 }, 422, 'INVALID_TICK'],
      [{ symbol: 'COMI', side: 'BUY', type: 'LIMIT', quantity: 1 }, 400, 'VALIDATION_ERROR'],
      [{ symbol: 'COMI', side: 'BUY', type: 'MARKET', targetPrice: '80', quantity: 1 }, 400, 'VALIDATION_ERROR'],
      [{ symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 1, validity: 'GTD' }, 400, 'VALIDATION_ERROR'],
      [{ symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 1, executionRule: 'MF' }, 400, 'VALIDATION_ERROR'],
      [{ symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 1, executionRule: 'FOK', validity: 'GTC' }, 400, 'VALIDATION_ERROR'],
      [{ symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 1, validity: 'GTD', validUntilDate: '2001-01-01' }, 422, 'INVALID_GTD_DATE'],
      [{ symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 1, custodianBank: 'Evil Bank' }, 422, 'INVALID_CUSTODIAN'],
      [{ symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 1, currency: 'USD' }, 422, 'CURRENCY_MISMATCH'],
      [{ symbol: 'NOPE', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 1 }, 404, 'NOT_FOUND'],
      [{ symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: -5 }, 400, 'VALIDATION_ERROR'],
      [{ symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 1.5 }, 400, 'VALIDATION_ERROR'],
    ];
    for (const [body, status, code] of cases) {
      const res = await place(u, body);
      expect({ body, status: res.status, code: res.body.error?.code }).toEqual({ body, status, code });
    }
    expect(await prisma.order.count()).toBe(0);
  });

  it('uses the USD wallet for USD-denominated stocks', async () => {
    await fund(u.id, 'USD', '500');
    const res = await place(u, { symbol: 'EKHO', side: 'BUY', type: 'LIMIT', targetPrice: '0.990', quantity: 100 });
    expect(res.status).toBe(201);
    expect(res.body.currency).toBe('USD');
    expect((await wallet(u.id, 'USD')).buyingPower.toFixed(4)).toBe((500 - 99 * 1.002).toFixed(4));
    expect((await wallet(u.id, 'EGP')).buyingPower.toFixed(2)).toBe('0.00');
  });

  it('RACE: 20 concurrent orders can never spend more than the available buying power', async () => {
    await fund(u.id, 'EGP', '10000'); // each order locks 30 × 80 × 1.002 = 2404.80 → exactly 4 fit
    const results = await Promise.all(
      Array.from({ length: 20 }, () => place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 30 })),
    );
    const statuses = results.map((r) => r.status);
    expect(statuses.filter((s) => s === 201)).toHaveLength(4);
    expect(statuses.filter((s) => s === 422)).toHaveLength(16);
    const w = await wallet(u.id);
    expect(w.buyingPower.toFixed(2)).toBe((10000 - 4 * 2404.8).toFixed(2));
    await assertBooksBalance();
  });

  it('RACE: concurrent SELL orders can never oversell a holding', async () => {
    await giveShares(u.id, 'COMI', 100);
    const results = await Promise.all(
      Array.from({ length: 6 }, () => place(u, { symbol: 'COMI', side: 'SELL', type: 'LIMIT', targetPrice: '85', quantity: 30 })),
    );
    expect(results.filter((r) => r.status === 201)).toHaveLength(3);
    expect(results.filter((r) => r.status === 422).every((r) => r.body.error.code === 'INSUFFICIENT_SHARES')).toBe(true);
    const h = await prisma.holding.findFirstOrThrow();
    expect(h.reservedQuantity).toBe(90);
    await assertBooksBalance();
  });

  it('Idempotency-Key makes retries safe', async () => {
    await fund(u.id, 'EGP', '10000');
    const headers = { 'Idempotency-Key': 'retry-key-12345' };
    const a = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 10 }, headers);
    const b = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 10 }, headers);
    expect(a.status).toBe(201);
    expect(b.status).toBe(200);
    expect(b.headers['idempotent-replayed']).toBe('true');
    expect(b.body.id).toBe(a.body.id);
    expect(await prisma.order.count()).toBe(1);
  });
});

describe('edit & cancel', () => {
  it('cancel releases exactly the locked buying power', async () => {
    await fund(u.id, 'EGP', '10000');
    const o = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '79.55', quantity: 37 });
    const del = await request(app).delete(`/api/v1/orders/${o.body.id}`).set(u.auth);
    expect(del.status).toBe(200);
    expect(del.body.status).toBe('CANCELLED');
    expect((await wallet(u.id)).buyingPower.toFixed(4)).toBe('10000.0000');
    const again = await request(app).delete(`/api/v1/orders/${o.body.id}`).set(u.auth);
    expect(again.status).toBe(409);
    await assertBooksBalance();
  });

  it('edit re-reserves the difference and refuses when funds are short', async () => {
    await fund(u.id, 'EGP', '10000');
    const o = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 50 });
    expect(o.body.lockedAmount).toBe('4008.0000');

    const up = await request(app).put(`/api/v1/orders/${o.body.id}`).set(u.auth).send({ quantity: 100 });
    expect(up.status).toBe(200);
    expect(up.body.lockedAmount).toBe('8016.0000');
    expect((await wallet(u.id)).buyingPower.toFixed(2)).toBe('1984.00');

    const tooMuch = await request(app).put(`/api/v1/orders/${o.body.id}`).set(u.auth).send({ quantity: 200 });
    expect(tooMuch.status).toBe(422);

    const down = await request(app).put(`/api/v1/orders/${o.body.id}`).set(u.auth).send({ targetPrice: '70' });
    expect(down.status).toBe(200);
    expect(down.body.lockedAmount).toBe('7014.0000');
    expect((await wallet(u.id)).buyingPower.toFixed(2)).toBe('2986.00');
    await assertBooksBalance();
  });

  it('edit of a SELL order adjusts reserved shares', async () => {
    await giveShares(u.id, 'COMI', 100);
    const o = await place(u, { symbol: 'COMI', side: 'SELL', type: 'LIMIT', targetPrice: '85', quantity: 40 });
    expect((await request(app).put(`/api/v1/orders/${o.body.id}`).set(u.auth).send({ quantity: 120 })).status).toBe(422);
    expect((await request(app).put(`/api/v1/orders/${o.body.id}`).set(u.auth).send({ quantity: 90 })).status).toBe(200);
    expect((await prisma.holding.findFirstOrThrow()).reservedQuantity).toBe(90);
    await assertBooksBalance();
  });

  it("users cannot see, edit or cancel someone else's order", async () => {
    await fund(u.id, 'EGP', '10000');
    const o = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 10 });
    const mallory = await registerUser('mallory');
    expect((await request(app).get(`/api/v1/orders/${o.body.id}`).set(mallory.auth)).status).toBe(404);
    expect((await request(app).delete(`/api/v1/orders/${o.body.id}`).set(mallory.auth)).status).toBe(404);
    expect((await request(app).put(`/api/v1/orders/${o.body.id}`).set(mallory.auth).send({ quantity: 1 })).status).toBe(404);
    expect((await request(app).get('/api/v1/orders').set(mallory.auth)).body.total).toBe(0);
  });
});

describe('execution rules (EGX)', () => {
  it('REGULAR limit buy walks the book, settles cash, fees and holdings', async () => {
    await fund(u.id, 'EGP', '10000');
    venue.setBook('COMI', [[79.8, 500]], [[79.9, 50], [80, 100], [80.1, 100]]);
    const res = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 100 });
    expect(res.body.status).toBe('EXECUTED');
    expect(res.body.filledQuantity).toBe(100);
    expect(res.body.averageFillPrice).toBe('79.9500');
    expect(res.body.lockedAmount).toBe('0.0000');
    // 50×79.9 + 50×80 = 7995, fee 0.2% = 15.99
    const w = await wallet(u.id);
    expect(w.cashBalance.toFixed(2)).toBe((10000 - 7995 - 15.99).toFixed(2));
    expect(w.buyingPower.toFixed(2)).toBe(w.cashBalance.toFixed(2));
    const h = await prisma.holding.findFirstOrThrow();
    expect(h.quantity).toBe(100);
    expect(h.averageBuyPrice.toFixed(4)).toBe('80.1099'); // cost incl. fees
    expect(await prisma.trade.count()).toBe(2);
    await assertBooksBalance();
  });

  it('FOK is killed when the full quantity is not available', async () => {
    await fund(u.id, 'EGP', '10000');
    venue.setBook('COMI', [], [[80, 50]]);
    const res = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 100, executionRule: 'FOK' });
    expect(res.body.status).toBe('CANCELLED');
    expect(res.body.filledQuantity).toBe(0);
    expect((await wallet(u.id)).buyingPower.toFixed(2)).toBe('10000.00');
    await assertBooksBalance();
  });

  it('FOK fills completely when liquidity is there', async () => {
    await fund(u.id, 'EGP', '10000');
    venue.setBook('COMI', [], [[80, 150]]);
    const res = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 100, executionRule: 'FOK' });
    expect(res.body.status).toBe('EXECUTED');
    await assertBooksBalance();
  });

  it('FAK fills what it can and cancels the rest', async () => {
    await fund(u.id, 'EGP', '10000');
    venue.setBook('COMI', [], [[80, 50]]);
    const res = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 100, executionRule: 'FAK' });
    expect(res.body.status).toBe('CANCELLED');
    expect(res.body.filledQuantity).toBe(50);
    expect((await prisma.holding.findFirstOrThrow()).quantity).toBe(50);
    await assertBooksBalance();
  });

  it('AON rests until the whole quantity can execute at once', async () => {
    await fund(u.id, 'EGP', '10000');
    venue.setBook('COMI', [], [[80, 50]]);
    const res = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 100, executionRule: 'AON' });
    expect(res.body.status).toBe('PENDING');
    expect(res.body.filledQuantity).toBe(0);

    venue.setBook('COMI', [], [[80, 200]]);
    await tick('COMI', null, '80');
    const o = await prisma.order.findUniqueOrThrow({ where: { id: res.body.id } });
    expect(o.status).toBe('EXECUTED');
    expect(o.filledQuantity).toBe(100);
    await assertBooksBalance();
  });

  it('MF needs its minimum on entry, then behaves like a regular order', async () => {
    await fund(u.id, 'EGP', '20000');
    venue.setBook('COMI', [], [[80, 50]]);
    const killed = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 100, executionRule: 'MF', minimumBlockQuantity: 60 });
    expect(killed.body.status).toBe('CANCELLED');
    expect(killed.body.cancelReason).toMatch(/MF/);

    venue.setBook('COMI', [], [[80, 50]]);
    const ok = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 100, executionRule: 'MF', minimumBlockQuantity: 40 });
    expect(ok.body.status).toBe('PARTIALLY_FILLED');
    expect(ok.body.filledQuantity).toBe(50);
    await assertBooksBalance();
  });

  it('conditional order (minimum block) waits for a large enough block', async () => {
    await fund(u.id, 'EGP', '10000');
    venue.setBook('COMI', [], [[80, 50]]);
    const res = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 100, minimumBlockQuantity: 60 });
    expect(res.body.status).toBe('PENDING');
    expect(res.body.filledQuantity).toBe(0);
    venue.setBook('COMI', [], [[80, 70]]);
    await tick('COMI', null, '80');
    const o = await prisma.order.findUniqueOrThrow({ where: { id: res.body.id } });
    expect(o.filledQuantity).toBe(70);
    expect(o.status).toBe('PARTIALLY_FILLED');
    await assertBooksBalance();
  });

  it('MARKET buy reserves a slippage buffer and returns what was not used', async () => {
    await fund(u.id, 'EGP', '10000');
    venue.setBook('COMI', [], [[80.1, 100]]);
    const res = await place(u, { symbol: 'COMI', side: 'BUY', type: 'MARKET', quantity: 100 });
    expect(res.body.status).toBe('EXECUTED');
    const w = await wallet(u.id);
    expect(w.cashBalance.toFixed(2)).toBe((10000 - 8010 - 16.02).toFixed(2));
    expect(w.buyingPower.toFixed(2)).toBe(w.cashBalance.toFixed(2));
    await assertBooksBalance();
  });

  it('MARKET order with no liquidity is cancelled, never left resting', async () => {
    await fund(u.id, 'EGP', '10000');
    const res = await place(u, { symbol: 'COMI', side: 'BUY', type: 'MARKET', quantity: 10 });
    expect(res.body.status).toBe('CANCELLED');
    expect((await wallet(u.id)).buyingPower.toFixed(2)).toBe('10000.00');
  });

  it('SELL execution credits proceeds minus fees and releases shares', async () => {
    await giveShares(u.id, 'COMI', 100);
    venue.setBook('COMI', [[85, 60], [84.9, 100]], []);
    const res = await place(u, { symbol: 'COMI', side: 'SELL', type: 'LIMIT', targetPrice: '84.9', quantity: 100 });
    expect(res.body.status).toBe('EXECUTED');
    const gross = 60 * 85 + 40 * 84.9;
    const w = await wallet(u.id);
    expect(w.cashBalance.toFixed(2)).toBe((gross - gross * 0.002).toFixed(2));
    expect(await prisma.holding.count()).toBe(0);
    // Cash credited by a sale was not a ledgered deposit in this test → reconcile manually
    const ledger = await prisma.ledgerEntry.aggregate({ _sum: { cashDelta: true } });
    expect(ledger._sum.cashDelta!.toFixed(2)).toBe(w.cashBalance.toFixed(2));
  });

  it('resting order executes on a later tick when the market reaches its price', async () => {
    await fund(u.id, 'EGP', '10000');
    venue.setBook('COMI', [], [[81, 500]]);
    const res = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 10 });
    expect(res.body.status).toBe('PENDING');
    venue.setBook('COMI', [], [[79.5, 500]]);
    await tick('COMI', null, '79.5');
    const o = await prisma.order.findUniqueOrThrow({ where: { id: res.body.id } });
    expect(o.status).toBe('EXECUTED');
    expect(o.averageFillPrice!.toFixed(2)).toBe('79.50'); // price improvement goes to the client
    await assertBooksBalance();
  });
});

describe('expiry', () => {
  it('DAY orders expire after their session closes and release funds; GTC orders do not', async () => {
    await fund(u.id, 'EGP', '10000');
    const day = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 10 });
    const gtc = await place(u, { symbol: 'COMI', side: 'BUY', type: 'LIMIT', targetPrice: '80', quantity: 10, validity: 'GTC' });
    const weekAgo = new Date(Date.now() - 7 * 86_400_000);
    await prisma.order.updateMany({ data: { createdAt: weekAgo } });

    expect(await expireOrders()).toBe(1);
    expect((await prisma.order.findUniqueOrThrow({ where: { id: day.body.id } })).status).toBe('CANCELLED');
    expect((await prisma.order.findUniqueOrThrow({ where: { id: gtc.body.id } })).status).toBe('PENDING');
    expect((await wallet(u.id)).buyingPower.toFixed(2)).toBe((10000 - 801.6).toFixed(2));
    await assertBooksBalance();
  });
});
