import { describe, expect, it } from 'vitest';
import { D } from '../src/lib/money';
import { isOnTick, priceBand } from '../src/market/rules';
import { sessionClosed, sessionDateFor } from '../src/market/session';
import { walkBook, type Book } from '../src/market/venue';
import { decide } from '../src/oms/engine';
import { lockAmountFor } from '../src/oms/settlement';

const o = (executionRule: 'REGULAR' | 'MF' | 'FOK' | 'FAK' | 'AON', extra: Partial<{ quantity: number; filledQuantity: number; minimumBlockQuantity: number | null; type: 'LIMIT' | 'MARKET' }> = {}) => ({
  executionRule, type: 'LIMIT' as const, quantity: 100, filledQuantity: 0, minimumBlockQuantity: null, ...extra,
});

describe('decide() — EGX execution conditions', () => {
  it('REGULAR fills what is available and rests', () => {
    expect(decide(o('REGULAR'), 40, true)).toMatchObject({ take: 40, cancelRest: false });
    expect(decide(o('REGULAR'), 0, true)).toMatchObject({ take: 0, cancelRest: false });
  });
  it('REGULAR with a minimum block waits for a big enough block', () => {
    expect(decide(o('REGULAR', { minimumBlockQuantity: 50 }), 40, false).take).toBe(0);
    expect(decide(o('REGULAR', { minimumBlockQuantity: 50 }), 60, false).take).toBe(60);
    // the final remainder may be smaller than the block
    expect(decide(o('REGULAR', { minimumBlockQuantity: 50, filledQuantity: 80 }), 20, false).take).toBe(20);
  });
  it('FOK is all or cancel', () => {
    expect(decide(o('FOK'), 100, true)).toMatchObject({ take: 100, cancelRest: false });
    expect(decide(o('FOK'), 99, true)).toMatchObject({ take: 0, cancelRest: true });
  });
  it('FAK takes what it can and cancels the rest', () => {
    expect(decide(o('FAK'), 30, true)).toMatchObject({ take: 30, cancelRest: true });
  });
  it('AON waits (limit) or cancels (market)', () => {
    expect(decide(o('AON'), 99, false)).toMatchObject({ take: 0, cancelRest: false });
    expect(decide(o('AON', { type: 'MARKET' }), 99, true)).toMatchObject({ take: 0, cancelRest: true });
    expect(decide(o('AON'), 100, false)).toMatchObject({ take: 100, cancelRest: false });
  });
  it('MF enforces its minimum on entry only', () => {
    expect(decide(o('MF', { minimumBlockQuantity: 50 }), 49, true)).toMatchObject({ take: 0, cancelRest: true });
    expect(decide(o('MF', { minimumBlockQuantity: 50 }), 50, true)).toMatchObject({ take: 50, cancelRest: false });
    expect(decide(o('MF', { minimumBlockQuantity: 50, filledQuantity: 50 }), 10, false)).toMatchObject({ take: 10 });
  });
  it('MARKET remainder never rests', () => {
    expect(decide(o('REGULAR', { type: 'MARKET' }), 30, true)).toMatchObject({ take: 30, cancelRest: true });
  });
});

describe('book walking', () => {
  const book: Book = {
    bids: [{ price: D(79.9), quantity: 10, orders: 1 }, { price: D(79.8), quantity: 10, orders: 1 }],
    asks: [{ price: D(80), quantity: 10, orders: 1 }, { price: D(80.1), quantity: 10, orders: 1 }],
  };
  it('respects limit prices on both sides', () => {
    expect(walkBook(book, 'BUY', D(80), 100).map((f) => f.quantity)).toEqual([10]);
    expect(walkBook(book, 'BUY', null, 15).map((f) => f.quantity)).toEqual([10, 5]);
    expect(walkBook(book, 'SELL', D(79.85), 100).map((f) => f.price.toFixed(2))).toEqual(['79.90']);
  });
});

describe('price rules', () => {
  it('reserves funds with fees, rounded up', () => {
    expect(lockAmountFor('BUY', 'LIMIT', 3, D('33.33'), D(0)).toFixed(4)).toBe('100.1900'); // 99.99 × 1.002 = 100.18998 → ceil
    expect(lockAmountFor('SELL', 'LIMIT', 3, D('33.33'), D(0)).toFixed(4)).toBe('0.0000');
  });
  it('validates ticks and the daily band', () => {
    expect(isOnTick(D('80.01'))).toBe(true);
    expect(isOnTick(D('80.015'))).toBe(false);
    expect(isOnTick(D('0.985'))).toBe(true);
    const band = priceBand(D(80));
    expect([band.min.toFixed(4), band.max.toFixed(4)]).toEqual(['64.0000', '96.0000']);
  });
});

describe('trading session calendar (Africa/Cairo)', () => {
  it('rolls orders placed after the close or on the weekend to the next session', () => {
    // 2026-10-27 is a Tuesday. 15:00 Cairo (UTC+3 → 12:00Z) is after the 14:30 close.
    expect(sessionDateFor(new Date('2026-10-27T09:00:00Z'))).toBe('2026-10-27');
    expect(sessionDateFor(new Date('2026-10-27T12:00:00Z'))).toBe('2026-10-28');
    // Friday → Sunday
    expect(sessionDateFor(new Date('2026-10-30T09:00:00Z'))).toBe('2026-11-01');
  });
  it('knows when a session has closed', () => {
    expect(sessionClosed('2026-10-27', new Date('2026-10-27T11:00:00Z'))).toBe(false);
    expect(sessionClosed('2026-10-27', new Date('2026-10-27T11:31:00Z'))).toBe(true);
    expect(sessionClosed('2026-10-27', new Date('2026-10-28T06:00:00Z'))).toBe(true);
  });
});
