import 'dotenv/config';
import { z } from 'zod';

const bool = z
  .enum(['true', 'false', '1', '0'])
  .transform((v) => v === 'true' || v === '1');

const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(4000),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  /** Comma-separated list of allowed browser origins. Mobile apps don't send Origin. */
  CORS_ORIGINS: z.string().default(''),
  /** Number of reverse proxies in front of the app (for correct client IPs in rate limiting). */
  TRUST_PROXY: z.coerce.number().int().min(0).default(0),

  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().default('redis://localhost:6379'),

  JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET must be at least 32 chars'),
  JWT_ACCESS_TTL: z.string().default('15m'),
  JWT_ISSUER: z.string().default('amalka-backend'),
  JWT_AUDIENCE: z.string().default('amalka-app'),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),
  BCRYPT_ROUNDS: z.coerce.number().int().min(10).max(15).default(12),

  // Rate limits (per IP, per minute)
  RATE_LIMIT_GLOBAL_PER_MIN: z.coerce.number().int().positive().default(300),
  RATE_LIMIT_AUTH_PER_MIN: z.coerce.number().int().positive().default(10),
  RATE_LIMIT_ORDERS_PER_MIN: z.coerce.number().int().positive().default(60),

  // Trading
  /** Brokerage commission + exchange fees as a fraction of trade value, e.g. 0.002 = 0.2%. */
  TRADING_FEE_RATE: z.coerce.number().min(0).max(0.05).default(0.002),
  /** Extra buying power reserved for MARKET buys to absorb price movement, e.g. 0.05 = 5%. */
  MARKET_BUY_BUFFER: z.coerce.number().min(0).max(0.5).default(0.05),
  /** Maximum allowed distance of a limit price from the last price (exchange price band), e.g. 0.2 = ±20%. */
  PRICE_BAND_PCT: z.coerce.number().min(0.01).max(1).default(0.2),
  MAX_ORDER_QUANTITY: z.coerce.number().int().positive().default(10_000_000),
  CUSTODIAN_BANKS: z.string().default('CIB Custody,NBE Custody,Banque Misr Custody,HSBC Custody,QNB Custody'),

  // Market session (EGX: Sunday–Thursday, Cairo time)
  MARKET_TIMEZONE: z.string().default('Africa/Cairo'),
  MARKET_OPEN: z.string().regex(/^\d{2}:\d{2}$/).default('10:00'),
  MARKET_CLOSE: z.string().regex(/^\d{2}:\d{2}$/).default('14:30'),
  /** 0=Sunday … 6=Saturday */
  MARKET_DAYS: z.string().default('0,1,2,3,4'),
  /** When true, MARKET orders are rejected and nothing executes outside the session. */
  ENFORCE_MARKET_HOURS: bool.default('false'),

  // Market data
  MARKET_FEED: z.enum(['simulator', 'none']).default('simulator'),
  MARKET_TICK_MS: z.coerce.number().int().min(200).default(1500),

  // Payments
  PUBLIC_BASE_URL: z.string().url().default('http://localhost:4000'),
  APP_RETURN_URL: z.string().default('amalka://payments/result'),
  MIN_DEPOSIT: z.coerce.number().positive().default(10),
  MAX_DEPOSIT: z.coerce.number().positive().default(1_000_000),
  PAYMENT_PROVIDER: z.enum(['paymob', 'paytabs']).default('paymob'),

  PAYMOB_BASE_URL: z.string().url().default('https://accept.paymob.com'),
  PAYMOB_SECRET_KEY: z.string().default(''),
  PAYMOB_PUBLIC_KEY: z.string().default(''),
  PAYMOB_HMAC_SECRET: z.string().default(''),
  PAYMOB_CARD_INTEGRATION_ID: z.string().default(''),

  PAYTABS_BASE_URL: z.string().url().default('https://secure-egypt.paytabs.com'),
  PAYTABS_PROFILE_ID: z.string().default(''),
  PAYTABS_SERVER_KEY: z.string().default(''),

  // Swagger
  SWAGGER_ENABLED: bool.default('true'),
});

const parsed = EnvSchema.safeParse(process.env);
if (!parsed.success) {
  // eslint-disable-next-line no-console
  console.error('❌ Invalid environment configuration:\n', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
export const isProd = env.NODE_ENV === 'production';
export const isTest = env.NODE_ENV === 'test';

export const custodianBanks = env.CUSTODIAN_BANKS.split(',').map((s) => s.trim()).filter(Boolean);
export const corsOrigins = env.CORS_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean);

if (isProd) {
  const weak = ['change-me', 'secret', 'dev'];
  if (weak.some((w) => env.JWT_ACCESS_SECRET.toLowerCase().includes(w))) {
    // eslint-disable-next-line no-console
    console.error('❌ Refusing to start in production with a placeholder JWT secret.');
    process.exit(1);
  }
}
