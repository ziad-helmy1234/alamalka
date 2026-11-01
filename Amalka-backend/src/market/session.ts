import { env } from '../config/env';

/**
 * EGX trading-session helpers. All calendar logic is done in the exchange's
 * timezone (Africa/Cairo by default), independent of the server's TZ.
 * Note: exchange holidays are not modelled — add a holiday calendar for production.
 */

const tradingDays = new Set(env.MARKET_DAYS.split(',').map((d) => Number(d.trim())));
const toMinutes = (hhmm: string) => {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
};
const OPEN_MIN = toMinutes(env.MARKET_OPEN);
const CLOSE_MIN = toMinutes(env.MARKET_CLOSE);

const fmt = new Intl.DateTimeFormat('en-US', {
  timeZone: env.MARKET_TIMEZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
  weekday: 'short',
});
const WEEKDAYS: Record<string, number> = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };

export interface LocalParts {
  date: string; // YYYY-MM-DD in exchange TZ
  weekday: number;
  minutes: number; // minutes since local midnight
}

export function localParts(d: Date): LocalParts {
  const p = Object.fromEntries(fmt.formatToParts(d).map((x) => [x.type, x.value]));
  return {
    date: `${p.year}-${p.month}-${p.day}`,
    weekday: WEEKDAYS[p.weekday as string],
    minutes: Number(p.hour) * 60 + Number(p.minute),
  };
}

function addDays(date: string, n: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

function weekdayOf(date: string): number {
  return new Date(`${date}T00:00:00Z`).getUTCDay();
}

export function isTradingDay(date: string): boolean {
  return tradingDays.has(weekdayOf(date));
}

export function isMarketOpen(now = new Date()): boolean {
  const p = localParts(now);
  return tradingDays.has(p.weekday) && p.minutes >= OPEN_MIN && p.minutes < CLOSE_MIN;
}

/** The trading date an order placed at `at` belongs to (orders placed after the close roll to the next session). */
export function sessionDateFor(at: Date): string {
  const p = localParts(at);
  let date = p.date;
  if (!tradingDays.has(p.weekday) || p.minutes >= CLOSE_MIN) date = addDays(date, 1);
  for (let i = 0; i < 7 && !isTradingDay(date); i++) date = addDays(date, 1);
  return date;
}

/** True once the closing bell of `sessionDate` (YYYY-MM-DD, exchange TZ) has rung. */
export function sessionClosed(sessionDate: string, now = new Date()): boolean {
  const p = localParts(now);
  if (p.date > sessionDate) return true;
  return p.date === sessionDate && p.minutes >= CLOSE_MIN;
}

export function todayLocal(now = new Date()): string {
  return localParts(now).date;
}

export function marketStatus(now = new Date()) {
  return {
    isOpen: isMarketOpen(now),
    timezone: env.MARKET_TIMEZONE,
    open: env.MARKET_OPEN,
    close: env.MARKET_CLOSE,
    enforced: env.ENFORCE_MARKET_HOURS,
  };
}
