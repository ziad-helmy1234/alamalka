import { redis } from '../lib/redis';
import { logger } from '../lib/logger';

/**
 * Event bus over Redis pub/sub so every API instance can push to the
 * WebSocket clients connected to it, regardless of which instance produced the event.
 */
export const CHANNELS = {
  ticks: 'md:ticks',
  user: (userId: string) => `user:${userId}`,
  userPattern: 'user:*',
  newOrder: 'oms:new-order',
} as const;

export type ServerEvent =
  | { type: 'tick'; data: TickPayload[] }
  | { type: 'order_update'; data: unknown }
  | { type: 'trade_execution'; data: unknown }
  | { type: 'price_alert'; data: unknown }
  | { type: 'wallet_update'; data: unknown };

export interface TickPayload {
  symbol: string;
  price: string;
  previousClose: string;
  change: string;
  changePct: number;
  open: string;
  high: string;
  low: string;
  volume: string;
  bid: string | null;
  ask: string | null;
  ts: number;
}

export async function publish(channel: string, event: ServerEvent | Record<string, unknown>): Promise<void> {
  try {
    await redis.publish(channel, JSON.stringify(event));
  } catch (err) {
    logger.warn({ err: (err as Error).message, channel }, 'publish failed');
  }
}

export const publishToUser = (userId: string, event: ServerEvent) => publish(CHANNELS.user(userId), event);
