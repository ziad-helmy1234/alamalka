import crypto from 'node:crypto';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import swaggerUi from 'swagger-ui-express';
import { corsOrigins, env, isProd } from './config/env';
import { openApiDocument } from './docs/openapi';
import { registry, z } from './docs/registry';
import { logger } from './lib/logger';
import { prisma } from './lib/prisma';
import { redis } from './lib/redis';
import { errorHandler, notFoundHandler } from './middleware/error';
import { rateLimit } from './middleware/rateLimit';
import { alertsRouter } from './modules/alerts/alerts.routes';
import { authRouter } from './modules/auth/auth.routes';
import { ordersRouter } from './modules/orders/orders.routes';
import { paymentsRouter, webhookHandler } from './modules/payments/payments.routes';
import { portfolioRouter } from './modules/portfolio/portfolio.routes';
import { stocksRouter } from './modules/stocks/stocks.routes';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', env.TRUST_PROXY);

  app.use((req, res, next) => {
    req.id = (req.get('x-request-id') ?? '').slice(0, 64) || crypto.randomUUID();
    req.valid = {};
    res.setHeader('X-Request-Id', req.id);
    const start = process.hrtime.bigint();
    res.on('finish', () => {
      const ms = Number(process.hrtime.bigint() - start) / 1e6;
      const level = res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'debug';
      logger[level]({ reqId: req.id, method: req.method, path: req.path, status: res.statusCode, ms: Math.round(ms) }, 'request');
    });
    next();
  });

  app.use(
    helmet({
      // Swagger UI needs inline scripts/styles; everything else is JSON.
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'", "'unsafe-inline'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", 'data:'],
        },
      },
    }),
  );
  app.use(
    cors({
      origin: (origin, cb) => {
        if (!origin) return cb(null, true); // native mobile apps / server-to-server send no Origin
        if (corsOrigins.length === 0) return cb(null, !isProd); // dev: any origin; prod: browsers must be allow-listed
        cb(null, corsOrigins.includes(origin));
      },
      methods: ['GET', 'POST', 'PUT', 'DELETE'],
      allowedHeaders: ['Authorization', 'Content-Type', 'Idempotency-Key', 'X-Request-Id'],
      maxAge: 600,
    }),
  );

  // Payment webhooks need the raw body for signature verification → registered before the JSON parser.
  app.post('/api/v1/payments/webhook', express.raw({ type: '*/*', limit: '256kb' }), webhookHandler);

  app.use(express.json({ limit: '100kb' }));
  app.use('/api', rateLimit({ name: 'global', limit: env.RATE_LIMIT_GLOBAL_PER_MIN }));

  // ---- System ----
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', uptime: Math.round(process.uptime()) });
  });
  app.get('/ready', async (_req, res) => {
    const [db, cache] = await Promise.allSettled([prisma.$queryRaw`SELECT 1`, redis.ping()]);
    const ok = db.status === 'fulfilled' && cache.status === 'fulfilled';
    res.status(ok ? 200 : 503).json({ status: ok ? 'ready' : 'degraded', database: db.status === 'fulfilled', redis: cache.status === 'fulfilled' });
  });

  // ---- API v1 ----
  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/stocks', stocksRouter);
  app.use('/api/v1/portfolio', portfolioRouter);
  app.use('/api/v1/orders', ordersRouter);
  app.use('/api/v1/payments', paymentsRouter);
  app.use('/api/v1/price-alerts', alertsRouter);

  // ---- Docs ----
  if (env.SWAGGER_ENABLED) {
    app.get('/api/docs.json', (_req, res) => {
      res.json(openApiDocument());
    });
    app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(openApiDocument(), { customSiteTitle: 'Amalka API' }));
  }

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}

registry.registerPath({
  method: 'get', path: '/health', tags: ['System'], summary: 'Liveness probe',
  responses: { 200: { description: 'OK', content: { 'application/json': { schema: z.object({ status: z.string(), uptime: z.number() }) } } } },
});
registry.registerPath({
  method: 'get', path: '/ready', tags: ['System'], summary: 'Readiness probe (Postgres + Redis)',
  responses: { 200: { description: 'Ready' }, 503: { description: 'Degraded' } },
});
