# Amalka Backend — EGX Trading API

Node.js + TypeScript (Express 5) backend for the Amalka Egyptian Exchange (EGX) trading app:
JWT auth, live market data over WebSockets, EGP/USD wallets, an order management system with EGX
execution rules, Paymob / PayTabs card deposits, withdrawals, and price alerts.

| Layer | Choice |
|---|---|
| API | Express 5, Zod validation, OpenAPI 3 (Swagger UI at `/api/docs`) |
| DB | PostgreSQL 16 via Prisma (NUMERIC money, CHECK-constraint invariants) |
| Cache / bus | Redis 7 (live quotes, rate limits, pub/sub fan-out, leader lock) |
| Realtime | `ws` gateway at `/ws/live-stocks` |
| Security | Helmet, CORS allow-list, Redis rate limits, bcrypt, short-lived JWT + rotating refresh tokens |

---

## Quick start (Windows / macOS / Linux)

Prerequisites: **Node.js 20+** and **Docker Desktop**.

```bash
cp .env.example .env            # Windows PowerShell: Copy-Item .env.example .env
# put a long random JWT_ACCESS_SECRET in .env:
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"

docker compose up -d            # Postgres (localhost:5433) + Redis (localhost:6380)
npm install
npx prisma migrate deploy       # create tables
npm run db:seed                 # 20 sample EGX stocks + demo users
npm run dev                     # http://localhost:4000
```

* Swagger UI: http://localhost:4000/api/docs
* Demo trader: `demo@amalka.app` / `Demo12345` (250,000 EGP + 10,000 USD)
* Demo admin: `admin@amalka.app` / `Admin12345`

Run the whole stack in containers instead: `docker compose --profile app up --build`.

### Tests

```bash
docker compose up -d
npm test
```

The suite recreates an `amalka_test` database and uses Redis DB 15. It covers auth (rotation, reuse
detection, revocation), every EGX execution rule, **concurrency races** (20 simultaneous orders against
one wallet, concurrent sells, concurrent duplicate webhooks), payments (signature verification, replay,
amount tampering), withdrawals, alerts, the WebSocket gateway, and asserts after each scenario that the
books reconcile: reserved cash = open BUY locks + pending withdrawals, cash = Σ ledger, reserved
shares = open SELL quantity.

---

## API overview (`/api/v1`)

| | Endpoint | Notes |
|---|---|---|
| Auth | `POST /auth/register` | creates user + EGP & USD wallets, returns tokens |
| | `POST /auth/login` | 5 failed attempts → 15 min lockout |
| | `POST /auth/refresh` | single-use refresh tokens; reuse revokes the session family |
| | `POST /auth/logout` | |
| | `POST /auth/change-password` | `oldPassword`, `newPassword`, `confirmPassword`; signs out other devices |
| Stocks | `GET /stocks` | `?sector=&q=&sharia=&currency=&sort=changePct&order=desc` |
| | `GET /stocks/sectors` | |
| | `GET /stocks/:symbol` | open/high/low, P/E, 52-week range, today's price limits |
| | `GET /stocks/:symbol/depth` | Level 2 bids/asks + recent trades |
| Portfolio | `GET /portfolio/summary` | per-currency cash, buying power, locked, holdings, P/L |
| Orders | `POST /orders` | supports `Idempotency-Key` header |
| | `GET /orders`, `GET /orders/:id` | `?status=OPEN|PENDING|…&symbol=&side=` |
| | `PUT /orders/:id` | edit price / quantity / validity of an open LIMIT order |
| | `DELETE /orders/:id` | cancel, releases reserved funds / shares |
| Payments | `POST /payments/card-intent` | Paymob Intention API or PayTabs hosted page |
| | `POST /payments/webhook` | HMAC-verified, idempotent crediting |
| | `GET /payments/transfers` | history |
| | `POST /payments/withdrawals` | holds funds; admin approves/rejects |
| Admin | `GET/POST /payments/admin/withdrawals…` | `ADMIN` role |
| Alerts | `POST/GET/DELETE /price-alerts` | fire once via WebSocket |

### WebSocket `/ws/live-stocks`

```js
const ws = new WebSocket('ws://localhost:4000/ws/live-stocks');
ws.onopen = () => {
  ws.send(JSON.stringify({ action: 'auth', token: accessToken }));          // optional: private events
  ws.send(JSON.stringify({ action: 'subscribe', symbols: ['COMI', 'TMGH'] })); // or ['*']
};
// server → client: tick | order_update | trade_execution | price_alert | wallet_update | auth_expired
```

---

## How the money stays correct

* **Buying power reservation.** A BUY locks `qty × price × (1 + fee)` (MARKET orders add `MARKET_BUY_BUFFER`).
  SELL orders reserve shares (`holdings.reserved_quantity`).
* **Row locks.** Every money movement runs in one transaction that takes `SELECT … FOR UPDATE` locks in a
  fixed order — order → transfer → portfolio — so concurrent requests serialize and can't deadlock.
* **Database guards.** CHECK constraints make overdrafts impossible even if code is wrong:
  `cash_balance ≥ 0`, `0 ≤ buying_power ≤ cash_balance`, `0 ≤ reserved_quantity ≤ quantity`, etc.
* **Ledger.** Every cash movement writes a `ledger_entries` row (deposits, settlements, fees, withdrawals).
* **Webhooks.** Signature verified over raw bytes; `payment_events (provider, event_key)` is unique, the
  transfer is locked, only `PENDING` transfers change, and amount + currency must match.
* **Decimals.** All money is `NUMERIC` in Postgres and `Decimal` in code; the API returns strings.

## EGX execution rules

| Rule | Behaviour |
|---|---|
| `REGULAR` | Partial fills allowed; rests until filled / expired. With `minimumBlockQuantity` each execution must be at least that block (تنفيذ بالدفعات). |
| `MF` | Minimum fill: on entry at least `minimumBlockQuantity` must fill, else cancelled. |
| `FOK` | Fill the whole quantity immediately or cancel. |
| `FAK` | Fill what's available immediately, cancel the rest. |
| `AON` | Only executes the full remaining quantity in one go (may rest if LIMIT). |
| Validity | `DAY` expires at the session close (orders after the close belong to the next session), `GTC`, `GTD` (+`validUntilDate`). |

Limit prices must be on the tick (0.01; 0.001 below 1 EGP) and inside ±`PRICE_BAND_PCT` of the previous close.

---

## ⚠️ Before going live

This codebase is production-grade in structure, but three things are outside what any backend can do alone:

1. **Order routing.** Retail apps cannot send orders to EGX directly; orders must go through a licensed
   brokerage (FRA-regulated) via its API/FIX gateway. The bundled `MarketSimulator` is the execution
   venue for development. Replace it with an `ExecutionVenue` that sends orders to your broker and feeds
   its execution reports into `applyFills()` / `cancelRemainder()` (`src/oms/settlement.ts`).
2. **Market data.** Replace the simulator feed with a licensed EGX data vendor. Seed prices, P/E ratios
   and Sharia flags in `prisma/seed.ts` are **sample values**.
3. **Rules & fees.** Confirm current tick sizes, price limits, session times, holidays (not modelled),
   T+ settlement, and your fee schedule with your broker; all are configurable in `.env`.

Also: put the API behind HTTPS (set `TRUST_PROXY`), set `ENFORCE_MARKET_HOURS=true`, keep secrets in a
secret manager, verify the Paymob/PayTabs payload fields against your sandbox before launch, and add
KYC/AML checks to registration and withdrawals as your licence requires.

## Project layout

```
prisma/            schema.prisma, migrations/, seed.ts
src/
  app.ts           express app (security middleware, routes, swagger)
  server.ts        http + websocket server, leader election, background jobs
  config/env.ts    validated configuration
  lib/             prisma (row locks, retrying tx), redis, tokens, money, errors
  middleware/      auth guard, zod validation, rate limit, error handler
  modules/         auth, stocks, portfolio, orders, payments, alerts
  oms/             settlement (money movement), matching engine (EGX rules), DTOs
  market/          session calendar, price rules, simulator / venue, quote cache
  realtime/        Redis event bus, WebSocket gateway
  jobs/            DAY/GTD order expiry
tests/             vitest + supertest integration tests
```
