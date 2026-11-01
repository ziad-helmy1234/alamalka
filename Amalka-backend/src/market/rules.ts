import { Prisma } from '@prisma/client';
import { env } from '../config/env';
import { D, type Dec } from '../lib/money';

/**
 * Exchange price rules. Values are configurable because EGX circulars change them;
 * confirm current tick sizes and price limits with your broker before going live.
 */

/** Minimum price increment. */
export function tickSize(price: Dec): Dec {
  if (price.lt(1)) return D('0.001');
  return D('0.01');
}

export function roundToTick(price: Dec): Dec {
  const t = tickSize(price);
  return price.div(t).toDecimalPlaces(0, Prisma.Decimal.ROUND_HALF_UP).times(t);
}

export function isOnTick(price: Dec): boolean {
  return price.mod(tickSize(price)).isZero();
}

/** Allowed limit-price range for the session, based on the previous close. */
export function priceBand(previousClose: Dec): { min: Dec; max: Dec } {
  return {
    min: previousClose.times(1 - env.PRICE_BAND_PCT).toDecimalPlaces(4, Prisma.Decimal.ROUND_UP),
    max: previousClose.times(1 + env.PRICE_BAND_PCT).toDecimalPlaces(4, Prisma.Decimal.ROUND_DOWN),
  };
}
