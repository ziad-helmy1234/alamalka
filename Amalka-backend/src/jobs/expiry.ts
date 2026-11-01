import { logger } from '../lib/logger';
import { prisma, withTx } from '../lib/prisma';
import { sessionClosed, sessionDateFor } from '../market/session';
import { engine } from '../oms/engine';
import { cancelRemainder, isOpen, lockOrder, OPEN_STATUSES } from '../oms/settlement';

/**
 * Expire DAY orders after the close of their session and GTD orders after the
 * close of their valid-until date, releasing reserved buying power / shares.
 */
export async function expireOrders(now = new Date()): Promise<number> {
  const candidates = await prisma.order.findMany({
    where: { status: { in: [...OPEN_STATUSES] }, validity: { in: ['DAY', 'GTD'] } },
    select: { id: true, validity: true, createdAt: true, validUntilDate: true },
    take: 1000,
  });

  let expired = 0;
  for (const c of candidates) {
    const session = c.validity === 'DAY' ? sessionDateFor(c.createdAt) : c.validUntilDate!.toISOString().slice(0, 10);
    if (!sessionClosed(session, now)) continue;
    const order = await withTx(async (tx) => {
      const o = await lockOrder(tx, c.id);
      if (!o || !isOpen(o)) return null;
      return cancelRemainder(tx, o, c.validity === 'DAY' ? 'Expired: end of trading day' : 'Expired: GTD date reached');
    });
    if (order) {
      expired++;
      await engine.emit(order, []);
    }
  }
  if (expired) logger.info({ expired }, 'orders expired');
  return expired;
}

export function startExpiryJob(intervalMs = 60_000): () => void {
  const timer = setInterval(() => void expireOrders().catch((err) => logger.error({ err }, 'expiry job failed')), intervalMs);
  void expireOrders().catch((err) => logger.error({ err }, 'expiry job failed'));
  return () => clearInterval(timer);
}
