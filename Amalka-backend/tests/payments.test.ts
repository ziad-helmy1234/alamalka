import crypto from 'node:crypto';
import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { prisma } from '../src/lib/prisma';
import { app, assertBooksBalance, fund, registerUser, resetDb, wallet, type TestUser } from './helpers';

const PAYMOB_HMAC = process.env.PAYMOB_HMAC_SECRET!;
const PAYTABS_KEY = process.env.PAYTABS_SERVER_KEY!;

let u: TestUser;
beforeEach(async () => {
  await resetDb();
  u = await registerUser();
});
afterEach(() => vi.unstubAllGlobals());

function mockGateway(body: unknown, status = 200) {
  const fetchMock = vi.fn(async () => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } }));
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}

async function startPaymobDeposit(amount = '1500.00') {
  const fetchMock = mockGateway({ id: 'pi_test_1', client_secret: 'egy_csk_test_abc', intention_order_id: 777001 });
  const res = await request(app).post('/api/v1/payments/card-intent').set(u.auth).send({ amount, currency: 'EGP' });
  expect(res.status).toBe(201);
  return { res, fetchMock };
}

/** Build a Paymob "transaction processed" callback signed exactly like Paymob does. */
function paymobCallback(transferId: string, amountCents: number, overrides: Record<string, unknown> = {}, txId = 9_000_001) {
  const obj: Record<string, any> = {
    id: txId, pending: false, amount_cents: amountCents, success: true, is_auth: false, is_capture: false,
    is_standalone_payment: true, is_voided: false, is_refunded: false, is_3d_secure: true, integration_id: 123456,
    has_parent_transaction: false, owner: 4242, error_occured: false, currency: 'EGP', created_at: '2026-10-27T13:00:00.000000',
    order: { id: 777001, merchant_order_id: transferId },
    source_data: { pan: '2346', type: 'card', sub_type: 'MasterCard' },
    data: { message: 'Approved' },
    ...overrides,
  };
  const fields = [
    obj.amount_cents, obj.created_at, obj.currency, obj.error_occured, obj.has_parent_transaction, obj.id, obj.integration_id,
    obj.is_3d_secure, obj.is_auth, obj.is_capture, obj.is_refunded, obj.is_standalone_payment, obj.is_voided, obj.order.id,
    obj.owner, obj.pending, obj.source_data.pan, obj.source_data.sub_type, obj.source_data.type, obj.success,
  ].map(String).join('');
  const hmac = crypto.createHmac('sha512', PAYMOB_HMAC).update(fields).digest('hex');
  return { body: { type: 'TRANSACTION', obj }, hmac };
}

const sendPaymob = (body: unknown, hmac: string) =>
  request(app).post(`/api/v1/payments/webhook?provider=paymob&hmac=${hmac}`).set('Content-Type', 'application/json').send(JSON.stringify(body));

describe('card deposits', () => {
  it('creates a Paymob intention and returns a checkout URL', async () => {
    const { res, fetchMock } = await startPaymobDeposit();
    expect(res.body.transferId).toMatch(/^TRF-\d+$/);
    expect(res.body.checkoutUrl).toContain('unifiedcheckout');
    expect(res.body.checkoutUrl).toContain('egy_csk_test_abc');
    const [url, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://accept.paymob.com/v1/intention/');
    const sent = JSON.parse(String(init.body));
    expect(sent.amount).toBe(150000);
    expect(sent.special_reference).toBe(res.body.transferId);
    expect((init.headers as Record<string, string>).Authorization).toBe('Token sk_test_paymob');
    const t = await prisma.transfer.findUniqueOrThrow({ where: { id: res.body.transferId } });
    expect(t.status).toBe('PENDING');
    expect(t.providerRef).toBe('777001');
  });

  it('marks the transfer FAILED when the gateway errors', async () => {
    mockGateway({ detail: 'bad key' }, 401);
    const res = await request(app).post('/api/v1/payments/card-intent').set(u.auth).send({ amount: '100', currency: 'EGP' });
    expect(res.status).toBe(502);
    expect((await prisma.transfer.findFirstOrThrow()).status).toBe('FAILED');
  });

  it('enforces deposit limits', async () => {
    const res = await request(app).post('/api/v1/payments/card-intent').set(u.auth).send({ amount: '1', currency: 'EGP' });
    expect(res.status).toBe(422);
  });

  it('signed webhook credits the wallet exactly once (replays are no-ops)', async () => {
    const { res } = await startPaymobDeposit('1500.00');
    const { body, hmac } = paymobCallback(res.body.transferId, 150000);

    const first = await sendPaymob(body, hmac);
    expect(first.status).toBe(200);
    expect(first.body.outcome).toBe('credited');
    const replay = await sendPaymob(body, hmac);
    expect(replay.status).toBe(200);
    expect(replay.body.outcome).toBe('duplicate');

    const w = await wallet(u.id);
    expect(w.cashBalance.toFixed(2)).toBe('1500.00');
    expect(w.buyingPower.toFixed(2)).toBe('1500.00');
    expect((await prisma.transfer.findUniqueOrThrow({ where: { id: res.body.transferId } })).status).toBe('COMPLETED');
    await assertBooksBalance();
  });

  it('concurrent duplicate webhooks still credit only once', async () => {
    const { res } = await startPaymobDeposit('1000.00');
    const { body, hmac } = paymobCallback(res.body.transferId, 100000);
    const results = await Promise.all(Array.from({ length: 5 }, () => sendPaymob(body, hmac)));
    expect(results.every((r) => r.status === 200)).toBe(true);
    expect((await wallet(u.id)).cashBalance.toFixed(2)).toBe('1000.00');
  });

  it('rejects forged / tampered webhooks', async () => {
    const { res } = await startPaymobDeposit('1500.00');
    const { body, hmac } = paymobCallback(res.body.transferId, 150000);
    (body.obj as any).amount_cents = 15000000; // attacker inflates the amount
    const tampered = await sendPaymob(body, hmac);
    expect(tampered.status).toBe(401);
    expect((await sendPaymob(body, 'deadbeef')).status).toBe(401);
    expect((await wallet(u.id)).cashBalance.toFixed(2)).toBe('0.00');
  });

  it('does not credit a correctly signed callback whose amount differs from the transfer', async () => {
    const { res } = await startPaymobDeposit('1500.00');
    const { body, hmac } = paymobCallback(res.body.transferId, 1);
    const r = await sendPaymob(body, hmac);
    expect(r.body.outcome).toBe('failed');
    expect((await wallet(u.id)).cashBalance.toFixed(2)).toBe('0.00');
    expect((await prisma.transfer.findFirstOrThrow()).status).toBe('FAILED');
  });

  it('declined payment marks the transfer FAILED', async () => {
    const { res } = await startPaymobDeposit('1500.00');
    const { body, hmac } = paymobCallback(res.body.transferId, 150000, { success: false, data: { message: 'Insufficient funds' } });
    expect((await sendPaymob(body, hmac)).body.outcome).toBe('failed');
    const t = await prisma.transfer.findFirstOrThrow();
    expect(t.status).toBe('FAILED');
    expect(t.failureReason).toBe('Insufficient funds');
  });

  it('PayTabs: creates a payment page and accepts a signed IPN', async () => {
    mockGateway({ tran_ref: 'TST2430001', redirect_url: 'https://secure-egypt.paytabs.com/payment/page/abc' });
    const res = await request(app).post('/api/v1/payments/card-intent').set(u.auth).send({ amount: '250.50', currency: 'EGP', provider: 'paytabs' });
    expect(res.status).toBe(201);
    expect(res.body.checkoutUrl).toContain('paytabs.com');

    const raw = JSON.stringify({ tran_ref: 'TST2430001', cart_id: res.body.transferId, cart_currency: 'EGP', cart_amount: '250.50', payment_result: { response_status: 'A', response_message: 'Authorised' } });
    const sig = crypto.createHmac('sha256', PAYTABS_KEY).update(raw).digest('hex');
    const ok = await request(app).post('/api/v1/payments/webhook?provider=paytabs').set('Content-Type', 'application/json').set('Signature', sig).send(raw);
    expect(ok.status).toBe(200);
    expect(ok.body.outcome).toBe('credited');
    expect((await wallet(u.id)).cashBalance.toFixed(2)).toBe('250.50');

    const bad = await request(app).post('/api/v1/payments/webhook?provider=paytabs').set('Content-Type', 'application/json').set('Signature', '00'.repeat(32)).send(raw);
    expect(bad.status).toBe(401);
  });
});

describe('withdrawals', () => {
  it('holds funds, then settles on approval', async () => {
    await fund(u.id, 'EGP', '5000');
    const w = await request(app).post('/api/v1/payments/withdrawals').set(u.auth)
      .send({ amount: '1200', currency: 'EGP', method: 'InstaPay', destination: 'mostafa@instapay' });
    expect(w.status).toBe(201);
    expect(w.body.destination).toMatch(/^•+apay$/);
    let p = await wallet(u.id);
    expect(p.cashBalance.toFixed(2)).toBe('5000.00');
    expect(p.buyingPower.toFixed(2)).toBe('3800.00');
    await assertBooksBalance();

    // trader cannot approve
    const forbidden = await request(app).post(`/api/v1/payments/admin/withdrawals/${w.body.id}/approve`).set(u.auth);
    expect(forbidden.status).toBe(403);

    // promote a second user to admin and log in again for a token carrying the role
    const admin = await registerUser('admin');
    await prisma.user.update({ where: { id: admin.id }, data: { role: 'ADMIN' } });
    const login = await request(app).post('/api/v1/auth/login').send({ email: admin.email, password: admin.password });
    const adminAuth = { Authorization: `Bearer ${login.body.accessToken}` };

    const list = await request(app).get('/api/v1/payments/admin/withdrawals').set(adminAuth);
    expect(list.body).toHaveLength(1);
    expect(list.body[0].destination).toBe('mostafa@instapay');

    const ok = await request(app).post(`/api/v1/payments/admin/withdrawals/${w.body.id}/approve`).set(adminAuth);
    expect(ok.status).toBe(200);
    expect(ok.body.status).toBe('COMPLETED');
    p = await wallet(u.id);
    expect(p.cashBalance.toFixed(2)).toBe('3800.00');
    expect(p.buyingPower.toFixed(2)).toBe('3800.00');
    expect((await request(app).post(`/api/v1/payments/admin/withdrawals/${w.body.id}/reject`).set(adminAuth).send({})).status).toBe(409);
    await assertBooksBalance();
  });

  it('rejected withdrawal releases the hold; overdraft is refused', async () => {
    await fund(u.id, 'EGP', '1000');
    const tooMuch = await request(app).post('/api/v1/payments/withdrawals').set(u.auth)
      .send({ amount: '1000.01', currency: 'EGP', method: 'Bank Transfer', destination: 'EG380019000500000000263180002' });
    expect(tooMuch.status).toBe(422);

    const w = await request(app).post('/api/v1/payments/withdrawals').set(u.auth)
      .send({ amount: '600', currency: 'EGP', method: 'Bank Transfer', destination: 'EG380019000500000000263180002' });
    const admin = await registerUser('admin');
    await prisma.user.update({ where: { id: admin.id }, data: { role: 'ADMIN' } });
    const login = await request(app).post('/api/v1/auth/login').send({ email: admin.email, password: admin.password });
    const rej = await request(app).post(`/api/v1/payments/admin/withdrawals/${w.body.id}/reject`)
      .set('Authorization', `Bearer ${login.body.accessToken}`).send({ reason: 'Name mismatch' });
    expect(rej.body.status).toBe('FAILED');
    const p = await wallet(u.id);
    expect(p.buyingPower.toFixed(2)).toBe('1000.00');
    await assertBooksBalance();
  });

  it('lists transfer history for the current user only', async () => {
    await fund(u.id, 'EGP', '100');
    const other = await registerUser('other');
    await fund(other.id, 'EGP', '100');
    const res = await request(app).get('/api/v1/payments/transfers').set(u.auth);
    expect(res.body.total).toBe(1);
  });
});
