import { Prisma, PrismaClient } from '@prisma/client';
import { logger } from './logger';

export const prisma = new PrismaClient({
  log: [
    { emit: 'event', level: 'warn' },
    { emit: 'event', level: 'error' },
  ],
});

prisma.$on('warn', (e) => logger.warn({ prisma: e }, 'prisma warning'));
prisma.$on('error', (e) => logger.error({ prisma: e }, 'prisma error'));

export type Tx = Prisma.TransactionClient;

/** Tables that may be row-locked via lockRow (whitelist — never interpolate user input). */
const LOCKABLE = {
  orders: { table: Prisma.raw('"orders"'), uuid: false },
  transfers: { table: Prisma.raw('"transfers"'), uuid: false },
  portfolios: { table: Prisma.raw('"portfolios"'), uuid: true },
  holdings: { table: Prisma.raw('"holdings"'), uuid: true },
} as const;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Acquire a row-level write lock (SELECT … FOR UPDATE) inside a transaction.
 * Lock order used everywhere to avoid deadlocks: orders → transfers → portfolios → holdings.
 * Returns false if the row does not exist.
 */
export async function lockRow(tx: Tx, table: keyof typeof LOCKABLE, id: string): Promise<boolean> {
  const t = LOCKABLE[table];
  if (t.uuid && !UUID_RE.test(id)) return false;
  const rows = t.uuid
    ? await tx.$queryRaw<{ id: string }[]>`SELECT "id"::text AS id FROM ${t.table} WHERE "id" = ${id}::uuid FOR UPDATE`
    : await tx.$queryRaw<{ id: string }[]>`SELECT "id" AS id FROM ${t.table} WHERE "id" = ${id} FOR UPDATE`;
  return rows.length > 0;
}

/** Run fn in a transaction, retrying on serialization failures / deadlocks. */
export async function withTx<T>(fn: (tx: Tx) => Promise<T>, opts: { retries?: number; timeoutMs?: number } = {}): Promise<T> {
  const retries = opts.retries ?? 3;
  for (let attempt = 0; ; attempt++) {
    try {
      // maxWait: time allowed to obtain a pooled connection (opening one can be slow on Docker Desktop / cold pools)
      return await prisma.$transaction(fn, { maxWait: 10_000, timeout: opts.timeoutMs ?? 15_000 });
    } catch (err) {
      const code = (err as { code?: string }).code;
      const msg = String((err as Error).message ?? '');
      const retryable = code === 'P2034' || msg.includes('deadlock detected') || msg.includes('could not serialize');
      if (!retryable || attempt >= retries) throw err;
      await new Promise((r) => setTimeout(r, 20 * 2 ** attempt + Math.random() * 20));
    }
  }
}
