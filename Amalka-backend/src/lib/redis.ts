import Redis from 'ioredis';
import { env } from '../config/env';
import { logger } from './logger';

function create(name: string): Redis {
  const client = new Redis(env.REDIS_URL, {
    lazyConnect: false,
    maxRetriesPerRequest: 3,
    enableAutoPipelining: true,
  });
  client.on('error', (err) => logger.error({ err: err.message, client: name }, 'redis error'));
  return client;
}

/** General-purpose commands (cache, rate limits, locks, publish). */
export const redis = create('main');
/** Dedicated subscriber connection (a subscribed connection cannot run other commands). */
export const redisSub = create('sub');

export async function closeRedis(): Promise<void> {
  await Promise.allSettled([redis.quit(), redisSub.quit()]);
}

/**
 * Simple single-leader lock so background jobs (market feed, matching, expiry)
 * run on exactly one instance when the API is horizontally scaled.
 */
export class LeaderLock {
  private timer?: NodeJS.Timeout;
  private _isLeader = false;
  private readonly token = `${process.pid}-${Math.random().toString(36).slice(2)}`;

  constructor(private readonly key: string, private readonly ttlMs = 10_000) {}

  get isLeader(): boolean {
    return this._isLeader;
  }

  start(onChange?: (leader: boolean) => void): void {
    const tick = async () => {
      try {
        let leader: boolean;
        if (this._isLeader) {
          // extend only if we still own it
          const res = await redis.eval(
            "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('pexpire', KEYS[1], ARGV[2]) else return 0 end",
            1,
            this.key,
            this.token,
            String(this.ttlMs),
          );
          leader = res === 1;
        } else {
          leader = (await redis.set(this.key, this.token, 'PX', this.ttlMs, 'NX')) === 'OK';
        }
        if (leader !== this._isLeader) {
          this._isLeader = leader;
          logger.info({ key: this.key, leader }, 'leader status changed');
          onChange?.(leader);
        }
      } catch (err) {
        logger.warn({ err: (err as Error).message }, 'leader lock tick failed');
      }
    };
    void tick();
    this.timer = setInterval(tick, Math.floor(this.ttlMs / 3));
  }

  async stop(): Promise<void> {
    if (this.timer) clearInterval(this.timer);
    if (this._isLeader) {
      await redis
        .eval("if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end", 1, this.key, this.token)
        .catch(() => undefined);
      this._isLeader = false;
    }
  }
}
