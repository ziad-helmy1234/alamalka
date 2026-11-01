import http from 'node:http';
import { createApp } from './app';
import { env } from './config/env';
import { startExpiryJob } from './jobs/expiry';
import { logger } from './lib/logger';
import { prisma } from './lib/prisma';
import { closeRedis, LeaderLock, redisSub } from './lib/redis';
import { MarketSimulator } from './market/simulator';
import { evaluateAlerts } from './modules/alerts/alerts.routes';
import { engine } from './oms/engine';
import { CHANNELS } from './realtime/events';
import { LiveGateway, WS_PATH } from './realtime/ws.gateway';

async function main() {
  await prisma.$connect();
  const app = createApp();
  const server = http.createServer(app);
  server.headersTimeout = 20_000;
  server.requestTimeout = 30_000;

  const gateway = new LiveGateway(server);
  await gateway.start();

  // ---- Background work runs on exactly one instance (the leader) ----
  let simulator: MarketSimulator | null = null;
  let stopExpiry: (() => void) | null = null;
  const leader = new LeaderLock('leader:market-engine', 15_000);

  // Orders placed on follower instances are forwarded here via Redis.
  await redisSub.subscribe(CHANNELS.newOrder);
  redisSub.on('message', (channel, message) => {
    if (channel !== CHANNELS.newOrder || !leader.isLeader) return;
    try {
      const { orderId, isEntry } = JSON.parse(message) as { orderId: string; isEntry: boolean };
      void engine.process(orderId, isEntry).catch((err) => logger.error({ err, orderId }, 'forwarded order failed'));
    } catch {
      /* ignore malformed */
    }
  });

  leader.start((isLeader) => {
    void (async () => {
      if (isLeader) {
        if (env.MARKET_FEED === 'simulator') {
          simulator = new MarketSimulator();
          simulator.onTick(async (ticks) => {
            await evaluateAlerts(ticks).catch((err) => logger.error({ err }, 'alert evaluation failed'));
            await engine.onTicks(ticks);
          });
          await simulator.start();
          engine.setVenue(simulator);
        }
        stopExpiry = startExpiryJob();
      } else {
        engine.setVenue(null);
        await simulator?.stop();
        simulator = null;
        stopExpiry?.();
        stopExpiry = null;
      }
    })().catch((err) => logger.error({ err }, 'leader transition failed'));
  });

  server.listen(env.PORT, () => {
    logger.info(`🚀 Amalka API on http://localhost:${env.PORT}  (docs: /api/docs, ws: ${WS_PATH})`);
  });

  let shuttingDown = false;
  const shutdown = async (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info({ signal }, 'shutting down');
    const force = setTimeout(() => process.exit(1), 15_000);
    force.unref();
    server.close();
    await gateway.stop().catch(() => undefined);
    await simulator?.stop();
    stopExpiry?.();
    await leader.stop();
    await prisma.$disconnect();
    await closeRedis();
    process.exit(0);
  };
  process.on('SIGTERM', () => void shutdown('SIGTERM'));
  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('unhandledRejection', (err) => logger.error({ err }, 'unhandled rejection'));
}

main().catch((err) => {
  logger.fatal({ err }, 'failed to start');
  process.exit(1);
});
