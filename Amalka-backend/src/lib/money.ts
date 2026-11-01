import { Prisma } from '@prisma/client';

export const D = (v: Prisma.Decimal.Value) => new Prisma.Decimal(v);
export type Dec = Prisma.Decimal;
export const ZERO = D(0);

/** Round half-up to 4 dp (DB scale for balances/prices). */
export const r4 = (v: Dec) => v.toDecimalPlaces(4, Prisma.Decimal.ROUND_HALF_UP);
/** Round half-up to 2 dp (display / gateway amounts). */
export const r2 = (v: Dec) => v.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
/** Round UP to 4 dp — used when reserving funds so a lock is never short by rounding. */
export const ceil4 = (v: Dec) => v.toDecimalPlaces(4, Prisma.Decimal.ROUND_UP);

export const toNum = (v: Dec | null | undefined) => (v == null ? null : Number(v.toString()));
export const toStr = (v: Dec | null | undefined) => (v == null ? null : v.toFixed(4));

/** Percentage change, 2 dp. */
export function pctChange(current: Dec, previous: Dec): number {
  if (previous.isZero()) return 0;
  return Number(current.minus(previous).div(previous).times(100).toFixed(2));
}
