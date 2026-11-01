import http from 'node:http';
import { AddressInfo } from 'node:net';
import request from 'supertest';
import WebSocket from 'ws';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { evaluateAlerts } from '../src/modules/alerts/alerts.routes';
import { CHANNELS, publish, publishToUser, type TickPayload } from '../src/realtime/events';
import { LiveGateway, WS_PATH } from '../src/realtime/ws.gateway';
import { prisma } from '../src/lib/prisma';
import { app, registerUser, resetDb, type TestUser } from './helpers';

const tick = (symbol: string, price: string): TickPayload => ({
  symbol, price, previousClose: '80', change: '0', changePct: 0, open: '80', high: price, low: price, volume: '0', bid: null, ask: null, ts: Date.now(),
});

let u: TestUser;
beforeEach(async () => {
  await resetDb();
  u = await registerUser();
});

describe('stocks', () => {
  it('lists stocks with change % and filters by sector / sharia / search', async () => {
    const all = await request(app).get('/api/v1/stocks');
    expect(all.status).toBe(200);
    expect(all.body.items.map((s: { symbol: string }) => s.symbol)).toEqual(['COMI', 'EKHO', 'TMGH']);
    expect(all.body.items[0]).toMatchObject({ price: '80', changePct: 0, currency: 'EGP' });

    const banks = await request(app).get('/api/v1/stocks?sector=banks');
    expect(banks.body.items).toHaveLength(1);
    const sharia = await request(app).get('/api/v1/stocks?sharia=true');
    expect(sharia.body.items.map((s: { symbol: string }) => s.symbol)).toEqual(['TMGH']);
    const search = await request(app).get(`/api/v1/stocks?q=${encodeURIComponent('طلعت')}`);
    expect(search.body.items[0].symbol).toBe('TMGH');
  });

  it('returns stock stats, price limits and the order book', async () => {
    const res = await request(app).get('/api/v1/stocks/comi');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ symbol: 'COMI', peRatio: '6.1000', week52High: '100.0000', week52Low: '55.0000' });
    expect(res.body.priceLimits).toEqual({ min: '64.0000', max: '96.0000' });

    const depth = await request(app).get('/api/v1/stocks/COMI/depth');
    expect(depth.status).toBe(200);
    expect(depth.body).toHaveProperty('bids');
    expect(depth.body).toHaveProperty('recentTrades');
    expect((await request(app).get('/api/v1/stocks/NOPE')).status).toBe(404);
    expect((await request(app).get('/api/v1/stocks/%27%3B--')).status).toBe(400);
  });
});

describe('portfolio', () => {
  it('summarises both wallets with valuation and P/L', async () => {
    const egp = await prisma.portfolio.findUniqueOrThrow({ where: { userId_currency: { userId: u.id, currency: 'EGP' } } });
    await prisma.portfolio.update({ where: { id: egp.id }, data: { cashBalance: 1000, buyingPower: 800 } });
    await prisma.holding.create({ data: { portfolioId: egp.id, symbol: 'COMI', quantity: 10, averageBuyPrice: '70' } });
    const res = await request(app).get('/api/v1/portfolio/summary').set(u.auth);
    expect(res.status).toBe(200);
    const w = res.body.wallets.find((x: { currency: string }) => x.currency === 'EGP');
    expect(w).toMatchObject({
      cashBalance: '1000.00', buyingPower: '800.00', lockedAmount: '200.00',
      holdingsValue: '800.00', totalEquity: '1800.00', unrealizedPnl: '100.00',
    });
    expect(w.holdings[0]).toMatchObject({ symbol: 'COMI', quantity: 10, marketValue: '800.00', unrealizedPnlPct: 14.29 });
    expect(res.body.wallets).toHaveLength(2);
  });
});

describe('price alerts', () => {
  it('creates, lists, triggers exactly once and deletes alerts', async () => {
    const up = await request(app).post('/api/v1/price-alerts').set(u.auth).send({ symbol: 'COMI', targetPrice: '85', condition: 'RISES_ABOVE' });
    expect(up.status).toBe(201);
    const down = await request(app).post('/api/v1/price-alerts').set(u.auth).send({ symbol: 'COMI', targetPrice: '75', condition: 'FALLS_BELOW' });
    expect((await request(app).get('/api/v1/price-alerts').set(u.auth)).body).toHaveLength(2);

    expect(await evaluateAlerts([tick('COMI', '84.99')])).toBe(0);
    expect(await evaluateAlerts([tick('COMI', '85.00')])).toBe(1);
    expect(await evaluateAlerts([tick('COMI', '86.00')])).toBe(0); // already fired
    expect(await evaluateAlerts([tick('COMI', '74.00')])).toBe(1);

    const active = await request(app).get('/api/v1/price-alerts').set(u.auth);
    expect(active.body).toHaveLength(0);
    const all = await request(app).get('/api/v1/price-alerts?includeTriggered=true').set(u.auth);
    expect(all.body).toHaveLength(2);

    expect((await request(app).delete(`/api/v1/price-alerts/${down.body.id}`).set(u.auth)).status).toBe(204);
    const other = await registerUser('other');
    expect((await request(app).delete(`/api/v1/price-alerts/${up.body.id}`).set(other.auth)).status).toBe(404);
    expect((await request(app).post('/api/v1/price-alerts').set(u.auth).send({ symbol: 'XXXX', targetPrice: '1', condition: 'RISES_ABOVE' })).status).toBe(404);
  });
});

describe('websocket gateway', () => {
  let server: http.Server;
  let gateway: LiveGateway;
  let url: string;

  beforeAll(async () => {
    server = http.createServer();
    gateway = new LiveGateway(server);
    await gateway.start();
    await new Promise<void>((r) => server.listen(0, r));
    url = `ws://127.0.0.1:${(server.address() as AddressInfo).port}${WS_PATH}`;
  });
  afterAll(async () => {
    await gateway.stop();
    server.close();
  });

  function connect(): Promise<{ ws: WebSocket; next: (type: string) => Promise<any> }> {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(url);
      const queue: any[] = [];
      const waiters: { type: string; resolve: (m: any) => void }[] = [];
      ws.on('message', (raw) => {
        const msg = JSON.parse(raw.toString());
        const i = waiters.findIndex((w) => w.type === msg.type);
        if (i >= 0) waiters.splice(i, 1)[0].resolve(msg);
        else queue.push(msg);
      });
      const next = (type: string) =>
        new Promise<any>((res, rej) => {
          const i = queue.findIndex((m) => m.type === type);
          if (i >= 0) return res(queue.splice(i, 1)[0]);
          waiters.push({ type, resolve: res });
          setTimeout(() => rej(new Error(`timeout waiting for ${type}`)), 4000);
        });
      ws.on('open', () => resolve({ ws, next }));
      ws.on('error', reject);
    });
  }

  it('streams ticks for subscribed symbols only', async () => {
    const { ws, next } = await connect();
    await next('welcome');
    ws.send(JSON.stringify({ action: 'subscribe', symbols: ['COMI'] }));
    await next('subscribed');
    await publish(CHANNELS.ticks, { type: 'tick', data: [tick('TMGH', '51'), tick('COMI', '81')] });
    const msg = await next('tick');
    expect(msg.data).toHaveLength(1);
    expect(msg.data[0].symbol).toBe('COMI');
    ws.close();
  });

  it('delivers private events only to the authenticated owner', async () => {
    const other = await registerUser('other');
    const a = await connect();
    const b = await connect();
    await a.next('welcome');
    await b.next('welcome');
    a.ws.send(JSON.stringify({ action: 'auth', token: u.accessToken }));
    b.ws.send(JSON.stringify({ action: 'auth', token: other.accessToken }));
    await a.next('authenticated');
    await b.next('authenticated');

    await publishToUser(u.id, { type: 'price_alert', data: { symbol: 'COMI' } });
    expect((await a.next('price_alert')).data.symbol).toBe('COMI');
    await expect(b.next('price_alert')).rejects.toThrow(/timeout/);
    a.ws.close();
    b.ws.close();
  });

  it('rejects bad tokens and unknown actions', async () => {
    const { ws, next } = await connect();
    await next('welcome');
    ws.send(JSON.stringify({ action: 'auth', token: 'garbage' }));
    expect((await next('error')).data.code).toBe('INVALID_TOKEN');
    ws.send(JSON.stringify({ action: 'drop_tables' }));
    expect((await next('error')).data.code).toBe('UNKNOWN_ACTION');
    ws.close();
  });
});

describe('docs & hardening', () => {
  it('serves the OpenAPI document with every endpoint', async () => {
    const res = await request(app).get('/api/docs.json');
    expect(res.status).toBe(200);
    const paths = Object.keys(res.body.paths);
    for (const p of [
      '/api/v1/auth/register', '/api/v1/auth/login', '/api/v1/auth/change-password', '/api/v1/stocks', '/api/v1/stocks/{symbol}',
      '/api/v1/stocks/{symbol}/depth', '/api/v1/portfolio/summary', '/api/v1/orders', '/api/v1/orders/{id}',
      '/api/v1/payments/card-intent', '/api/v1/payments/webhook', '/api/v1/price-alerts', '/api/v1/price-alerts/{id}',
    ]) expect(paths).toContain(p);
    expect((await request(app).get('/api/docs/')).status).toBe(200);
  });

  it('sets security headers and hides the framework', async () => {
    const res = await request(app).get('/health');
    expect(res.headers['x-powered-by']).toBeUndefined();
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-request-id']).toBeTruthy();
  });

  it('handles malformed JSON and unknown routes cleanly', async () => {
    const bad = await request(app).post('/api/v1/auth/login').set('Content-Type', 'application/json').send('{"email":');
    expect(bad.status).toBe(400);
    expect(bad.body.error.code).toBe('INVALID_JSON');
    expect((await request(app).get('/api/v1/nothing')).status).toBe(404);
  });

  it('reports readiness of Postgres and Redis', async () => {
    const res = await request(app).get('/ready');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ready', database: true, redis: true });
  });
});
