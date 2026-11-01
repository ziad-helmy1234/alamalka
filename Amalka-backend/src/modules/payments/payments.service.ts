import type { Currency } from '@prisma/client';
import { env } from '../../config/env';
import { AppError, Conflict, NotFound, Unprocessable } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { D, r2 } from '../../lib/money';
import { lockRow, prisma, withTx } from '../../lib/prisma';
import { transferDto, walletDto } from '../../oms/dto';
import { lockPortfolio } from '../../oms/settlement';
import { publishToUser } from '../../realtime/events';
import { paymob, paytabs, type NormalizedPaymentEvent } from './gateways';

const gateway = (p: 'paymob' | 'paytabs') => (p === 'paymob' ? paymob : paytabs);

async function wallet(userId: string, currency: Currency) {
  const w = await prisma.portfolio.findUnique({ where: { userId_currency: { userId, currency } } });
  if (!w) throw NotFound(`${currency} wallet`);
  return w;
}

function checkAmount(amount: string): string {
  const a = r2(D(amount));
  if (a.lt(env.MIN_DEPOSIT) || a.gt(env.MAX_DEPOSIT)) {
    throw Unprocessable('INVALID_AMOUNT', `Amount must be between ${env.MIN_DEPOSIT} and ${env.MAX_DEPOSIT}`);
  }
  return a.toFixed(2);
}

export async function createCardIntent(
  userId: string,
  input: { amount: string; currency: Currency; provider?: 'paymob' | 'paytabs'; phone?: string },
) {
  const providerName = input.provider ?? env.PAYMENT_PROVIDER;
  const gw = gateway(providerName);
  if (!gw.configured()) throw new AppError(503, 'PAYMENTS_NOT_CONFIGURED', `${providerName} credentials are not configured`);

  const amount = checkAmount(input.amount);
  const [user, w] = await Promise.all([prisma.user.findUniqueOrThrow({ where: { id: userId } }), wallet(userId, input.currency)]);

  const transfer = await prisma.transfer.create({
    data: {
      userId,
      portfolioId: w.id,
      amount,
      currency: input.currency,
      type: 'DEPOSIT',
      method: 'Card',
      provider: providerName === 'paymob' ? 'PAYMOB' : 'PAYTABS',
    },
  });

  try {
    const [firstName, ...rest] = user.fullNameEn.split(' ');
    const session = await gw.createCheckout({
      transferId: transfer.id,
      amount,
      currency: input.currency,
      customer: { email: user.email, firstName: firstName || 'Customer', lastName: rest.join(' ') || 'Amalka', phone: input.phone },
    });
    await prisma.transfer.update({ where: { id: transfer.id }, data: { providerRef: session.providerRef } });
    return {
      transferId: transfer.id,
      provider: providerName,
      amount,
      currency: input.currency,
      status: 'PENDING' as const,
      checkoutUrl: session.checkoutUrl,
      clientSecret: session.clientSecret ?? null,
    };
  } catch (err) {
    await prisma.transfer.update({
      where: { id: transfer.id },
      data: { status: 'FAILED', failureReason: 'Could not create payment session' },
    });
    throw err;
  }
}

/**
 * Verified webhook → credit wallet. Exactly-once by construction:
 *  1. payment_events has UNIQUE(provider, event_key): a replayed callback fails the insert;
 *  2. the transfer row is locked and only a PENDING transfer can change state;
 *  3. all of it commits atomically (a crash mid-way rolls back, and the provider's retry re-applies).
 */
export async function handleWebhook(rawBody: Buffer, query: Record<string, unknown>, headers: Record<string, unknown>) {
  const hinted = typeof query.provider === 'string' ? query.provider.toLowerCase() : undefined;
  const provider = hinted === 'paytabs' || (!hinted && headers.signature) ? 'paytabs' : 'paymob';
  const gw = gateway(provider);
  if (!gw.configured()) throw new AppError(503, 'PAYMENTS_NOT_CONFIGURED', `${provider} is not configured`);

  const ev: NormalizedPaymentEvent =
    provider === 'paymob' ? paymob.verifyAndParse(rawBody, query) : paytabs.verifyAndParse(rawBody, headers);

  const result = await withTx(async (tx) => {
    // INSERT … ON CONFLICT DO NOTHING: a concurrent duplicate waits for the first transaction, then inserts nothing.
    const inserted = await tx.paymentEvent.createMany({
      data: [{ provider: ev.provider, eventKey: ev.eventKey, transferId: ev.transferId, payload: JSON.parse(rawBody.toString('utf8')) }],
      skipDuplicates: true,
    });
    if (inserted.count === 0) return { outcome: 'duplicate' as const };

    const transfer =
      (ev.transferId && (await tx.transfer.findUnique({ where: { id: ev.transferId } }))) ||
      (ev.providerRef && (await tx.transfer.findUnique({ where: { providerRef: ev.providerRef } }))) ||
      null;
    if (!transfer || transfer.type !== 'DEPOSIT') {
      logger.warn({ ev }, 'payment webhook for unknown transfer');
      return { outcome: 'unknown_transfer' as const };
    }

    await lockRow(tx, 'transfers', transfer.id);
    const current = await tx.transfer.findUniqueOrThrow({ where: { id: transfer.id } });
    if (current.status !== 'PENDING') return { outcome: 'already_final' as const, transfer: current };

    const expectedMinor = Math.round(Number(current.amount) * 100);
    const amountOk = ev.amountMinor === expectedMinor && ev.currency.toUpperCase() === current.currency;

    if (!ev.success || !amountOk) {
      const reason = !amountOk ? `Amount/currency mismatch (got ${ev.amountMinor} ${ev.currency})` : ev.reason ?? 'Payment failed';
      if (!amountOk) logger.error({ ev, transferId: current.id }, 'payment amount mismatch — not crediting');
      const failed = await tx.transfer.update({ where: { id: current.id }, data: { status: 'FAILED', failureReason: reason.slice(0, 200) } });
      return { outcome: 'failed' as const, transfer: failed };
    }

    await lockPortfolio(tx, current.portfolioId);
    const w = await tx.portfolio.update({
      where: { id: current.portfolioId },
      data: { cashBalance: { increment: current.amount }, buyingPower: { increment: current.amount } },
    });
    await tx.ledgerEntry.create({
      data: { portfolioId: w.id, type: 'DEPOSIT', cashDelta: current.amount, buyingPowerDelta: current.amount, cashBalanceAfter: w.cashBalance, refId: current.id },
    });
    const done = await tx.transfer.update({
      where: { id: current.id },
      data: { status: 'COMPLETED', providerRef: current.providerRef ?? ev.providerRef },
    });
    return { outcome: 'credited' as const, transfer: done, wallet: w };
  });

  if ('transfer' in result && result.transfer) {
    const t = result.transfer;
    const w = 'wallet' in result && result.wallet ? result.wallet : await prisma.portfolio.findUnique({ where: { id: t.portfolioId } });
    await publishToUser(t.userId, { type: 'wallet_update', data: { transfer: transferDto(t), wallet: w ? walletDto(w) : null } });
  }
  logger.info({ provider, eventKey: ev.eventKey, outcome: result.outcome }, 'payment webhook processed');
  return { received: true, outcome: result.outcome };
}

// ------------------------------- Withdrawals -------------------------------

export async function requestWithdrawal(
  userId: string,
  input: { amount: string; currency: Currency; method: string; destination: string },
) {
  const amount = r2(D(input.amount));
  if (amount.lte(0)) throw Unprocessable('INVALID_AMOUNT', 'Amount must be positive');
  const w = await wallet(userId, input.currency);

  const transfer = await withTx(async (tx) => {
    const p = await lockPortfolio(tx, w.id);
    if (p.buyingPower.lt(amount)) {
      throw Unprocessable('INSUFFICIENT_FUNDS', 'Withdrawal exceeds available balance', { available: p.buyingPower.toFixed(2) });
    }
    // Hold the funds now; cash leaves the wallet when an operator settles the payout.
    const after = await tx.portfolio.update({ where: { id: p.id }, data: { buyingPower: { decrement: amount } } });
    const t = await tx.transfer.create({
      data: {
        userId, portfolioId: p.id, amount, currency: input.currency, type: 'WITHDRAWAL',
        method: input.method, destination: input.destination, provider: 'MANUAL',
      },
    });
    await tx.ledgerEntry.create({
      data: { portfolioId: p.id, type: 'WITHDRAWAL_HOLD', cashDelta: 0, buyingPowerDelta: amount.neg(), cashBalanceAfter: after.cashBalance, refId: t.id },
    });
    return t;
  });
  return transferDto(transfer);
}

export async function resolveWithdrawal(transferId: string, approve: boolean, reason?: string) {
  const res = await withTx(async (tx) => {
    if (!(await lockRow(tx, 'transfers', transferId))) throw NotFound('Transfer');
    const t = await tx.transfer.findUniqueOrThrow({ where: { id: transferId } });
    if (t.type !== 'WITHDRAWAL') throw NotFound('Withdrawal');
    if (t.status !== 'PENDING') throw Conflict('TRANSFER_NOT_PENDING', `Withdrawal is already ${t.status}`);
    await lockPortfolio(tx, t.portfolioId);
    let w;
    if (approve) {
      w = await tx.portfolio.update({ where: { id: t.portfolioId }, data: { cashBalance: { decrement: t.amount } } });
      await tx.ledgerEntry.create({
        data: { portfolioId: w.id, type: 'WITHDRAWAL_SETTLED', cashDelta: t.amount.neg(), buyingPowerDelta: 0, cashBalanceAfter: w.cashBalance, refId: t.id },
      });
    } else {
      w = await tx.portfolio.update({ where: { id: t.portfolioId }, data: { buyingPower: { increment: t.amount } } });
      await tx.ledgerEntry.create({
        data: { portfolioId: w.id, type: 'WITHDRAWAL_RELEASE', cashDelta: 0, buyingPowerDelta: t.amount, cashBalanceAfter: w.cashBalance, refId: t.id },
      });
    }
    const updated = await tx.transfer.update({
      where: { id: t.id },
      data: approve ? { status: 'COMPLETED' } : { status: 'FAILED', failureReason: (reason ?? 'Rejected').slice(0, 200) },
    });
    return { transfer: updated, wallet: w };
  });
  await publishToUser(res.transfer.userId, { type: 'wallet_update', data: { transfer: transferDto(res.transfer), wallet: walletDto(res.wallet) } });
  return transferDto(res.transfer);
}

export async function listTransfers(userId: string, q: { page: number; limit: number; type?: 'DEPOSIT' | 'WITHDRAWAL' }) {
  const where = { userId, type: q.type };
  const [items, total] = await Promise.all([
    prisma.transfer.findMany({ where, orderBy: { createdAt: 'desc' }, skip: (q.page - 1) * q.limit, take: q.limit }),
    prisma.transfer.count({ where }),
  ]);
  return { items: items.map(transferDto), page: q.page, limit: q.limit, total };
}

export async function listPendingWithdrawals() {
  const items = await prisma.transfer.findMany({
    where: { type: 'WITHDRAWAL', status: 'PENDING' },
    orderBy: { createdAt: 'asc' },
    include: { user: { select: { email: true, unifiedId: true, fullNameEn: true } } },
    take: 200,
  });
  // Admins see the full destination to execute the payout.
  return items.map((t) => ({ ...transferDto(t), destination: t.destination, user: t.user }));
}
