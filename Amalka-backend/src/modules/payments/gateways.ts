import crypto from 'node:crypto';
import type { Currency } from '@prisma/client';
import { env } from '../../config/env';
import { AppError } from '../../lib/errors';
import { logger } from '../../lib/logger';

/** Provider-agnostic shape of a verified payment callback. */
export interface NormalizedPaymentEvent {
  provider: 'PAYMOB' | 'PAYTABS';
  /** Provider transaction id — unique per provider, used for replay protection. */
  eventKey: string;
  /** Our transfer id (sent to the gateway as merchant reference). */
  transferId: string | null;
  /** Gateway-side order/transaction reference stored on the transfer. */
  providerRef: string | null;
  /** Amount in minor units (piasters / cents). */
  amountMinor: number;
  currency: string;
  success: boolean;
  reason: string | null;
}

export interface CheckoutSession {
  providerRef: string;
  checkoutUrl: string;
  clientSecret?: string;
}

export interface CheckoutRequest {
  transferId: string;
  amount: string; // major units, 2 dp
  currency: Currency;
  customer: { email: string; firstName: string; lastName: string; phone?: string };
}

const webhookUrl = (provider: string) => `${env.PUBLIC_BASE_URL}/api/v1/payments/webhook?provider=${provider}`;
const toMinor = (amount: string) => Math.round(Number(amount) * 100);

/** Constant-time comparison of two hex digests. */
function safeEqualHex(a: string, b: string): boolean {
  const ab = Buffer.from(a.toLowerCase(), 'utf8');
  const bb = Buffer.from(b.toLowerCase(), 'utf8');
  return ab.length === bb.length && crypto.timingSafeEqual(ab, bb);
}

async function postJson(url: string, body: unknown, headers: Record<string, string>): Promise<any> {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(15_000),
  });
  const text = await res.text();
  let data: any;
  try {
    data = JSON.parse(text);
  } catch {
    data = { raw: text.slice(0, 500) };
  }
  if (!res.ok) {
    logger.error({ url, status: res.status, data }, 'payment gateway error');
    throw new AppError(502, 'GATEWAY_ERROR', 'Payment provider rejected the request');
  }
  return data;
}

// ============================== Paymob (Intention API) ==============================

export const paymob = {
  configured: () => Boolean(env.PAYMOB_SECRET_KEY && env.PAYMOB_PUBLIC_KEY && env.PAYMOB_HMAC_SECRET && env.PAYMOB_CARD_INTEGRATION_ID),

  async createCheckout(req: CheckoutRequest): Promise<CheckoutSession> {
    const cents = toMinor(req.amount);
    const data = await postJson(
      `${env.PAYMOB_BASE_URL}/v1/intention/`,
      {
        amount: cents,
        currency: req.currency,
        payment_methods: [Number(env.PAYMOB_CARD_INTEGRATION_ID)],
        items: [{ name: 'Wallet deposit', amount: cents, description: `Deposit ${req.transferId}`, quantity: 1 }],
        billing_data: {
          first_name: req.customer.firstName,
          last_name: req.customer.lastName,
          email: req.customer.email,
          phone_number: req.customer.phone ?? 'NA',
          apartment: 'NA', floor: 'NA', street: 'NA', building: 'NA', city: 'NA', state: 'NA', country: 'EG',
        },
        special_reference: req.transferId,
        notification_url: webhookUrl('paymob'),
        redirection_url: env.APP_RETURN_URL,
      },
      { Authorization: `Token ${env.PAYMOB_SECRET_KEY}` },
    );
    if (!data.client_secret) throw new AppError(502, 'GATEWAY_ERROR', 'Payment provider returned no client secret');
    return {
      providerRef: String(data.intention_order_id ?? data.id),
      clientSecret: data.client_secret,
      checkoutUrl: `${env.PAYMOB_BASE_URL}/unifiedcheckout/?publicKey=${encodeURIComponent(env.PAYMOB_PUBLIC_KEY)}&clientSecret=${encodeURIComponent(data.client_secret)}`,
    };
  },

  /**
   * "Transaction processed" callback: HMAC-SHA512 over these fields' values, concatenated
   * in this exact order, keyed with the HMAC secret; sent as ?hmac=… .
   */
  verifyAndParse(rawBody: Buffer, query: Record<string, unknown>): NormalizedPaymentEvent {
    const hmac = typeof query.hmac === 'string' ? query.hmac : '';
    let payload: any;
    try {
      payload = JSON.parse(rawBody.toString('utf8'));
    } catch {
      throw new AppError(400, 'INVALID_PAYLOAD', 'Invalid JSON');
    }
    const o = payload?.obj;
    if (!hmac || !o) throw new AppError(401, 'INVALID_SIGNATURE', 'Missing signature');

    const v = (x: unknown) => (x === null || x === undefined ? '' : String(x));
    const concatenated = [
      o.amount_cents, o.created_at, o.currency, o.error_occured, o.has_parent_transaction, o.id,
      o.integration_id, o.is_3d_secure, o.is_auth, o.is_capture, o.is_refunded, o.is_standalone_payment,
      o.is_voided, o.order?.id, o.owner, o.pending, o.source_data?.pan, o.source_data?.sub_type,
      o.source_data?.type, o.success,
    ].map(v).join('');
    const expected = crypto.createHmac('sha512', env.PAYMOB_HMAC_SECRET).update(concatenated).digest('hex');
    if (!safeEqualHex(expected, hmac)) throw new AppError(401, 'INVALID_SIGNATURE', 'Signature mismatch');

    const success = o.success === true && o.pending !== true && o.error_occured !== true && o.is_voided !== true && o.is_refunded !== true;
    return {
      provider: 'PAYMOB',
      eventKey: String(o.id),
      transferId: o.order?.merchant_order_id ? String(o.order.merchant_order_id) : null,
      providerRef: o.order?.id != null ? String(o.order.id) : null,
      amountMinor: Number(o.amount_cents),
      currency: String(o.currency),
      success,
      reason: success ? null : String(o.data?.message ?? o.data?.txn_response_code ?? 'Payment declined').slice(0, 200),
    };
  },
};

// ============================== PayTabs (Hosted Payment Page) ==============================

export const paytabs = {
  configured: () => Boolean(env.PAYTABS_PROFILE_ID && env.PAYTABS_SERVER_KEY),

  async createCheckout(req: CheckoutRequest): Promise<CheckoutSession> {
    const data = await postJson(
      `${env.PAYTABS_BASE_URL}/payment/request`,
      {
        profile_id: Number(env.PAYTABS_PROFILE_ID),
        tran_type: 'sale',
        tran_class: 'ecom',
        cart_id: req.transferId,
        cart_currency: req.currency,
        cart_amount: Number(req.amount),
        cart_description: `Wallet deposit ${req.transferId}`,
        callback: webhookUrl('paytabs'),
        return: env.APP_RETURN_URL,
        hide_shipping: true,
        customer_details: {
          name: `${req.customer.firstName} ${req.customer.lastName}`.trim(),
          email: req.customer.email,
          phone: req.customer.phone ?? '',
          country: 'EG',
        },
      },
      { authorization: env.PAYTABS_SERVER_KEY },
    );
    if (!data.redirect_url || !data.tran_ref) throw new AppError(502, 'GATEWAY_ERROR', 'Payment provider returned no redirect URL');
    return { providerRef: String(data.tran_ref), checkoutUrl: String(data.redirect_url) };
  },

  /** IPN/callback: `Signature` header = HMAC-SHA256(raw request body, server key), hex. */
  verifyAndParse(rawBody: Buffer, headers: Record<string, unknown>): NormalizedPaymentEvent {
    const sig = typeof headers.signature === 'string' ? headers.signature : '';
    if (!sig) throw new AppError(401, 'INVALID_SIGNATURE', 'Missing signature');
    const expected = crypto.createHmac('sha256', env.PAYTABS_SERVER_KEY).update(rawBody).digest('hex');
    if (!safeEqualHex(expected, sig)) throw new AppError(401, 'INVALID_SIGNATURE', 'Signature mismatch');

    let p: any;
    try {
      p = JSON.parse(rawBody.toString('utf8'));
    } catch {
      throw new AppError(400, 'INVALID_PAYLOAD', 'Invalid JSON');
    }
    const status = p?.payment_result?.response_status;
    const success = status === 'A';
    return {
      provider: 'PAYTABS',
      eventKey: String(p.tran_ref),
      transferId: p.cart_id ? String(p.cart_id) : null,
      providerRef: p.tran_ref ? String(p.tran_ref) : null,
      amountMinor: Math.round(Number(p.cart_amount) * 100),
      currency: String(p.cart_currency),
      success,
      reason: success ? null : String(p?.payment_result?.response_message ?? `Status ${status}`).slice(0, 200),
    };
  },
};
