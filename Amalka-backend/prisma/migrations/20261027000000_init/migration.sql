-- Amalka EGX backend: initial schema.

-- Human-readable id sequences (EGX-100001, ORD-100001, TRF-100001)
CREATE SEQUENCE "unified_id_seq" START 100001;
CREATE SEQUENCE "order_id_seq" START 100001;
CREATE SEQUENCE "transfer_id_seq" START 100001;

-- CreateEnum
CREATE TYPE "Role" AS ENUM ('TRADER', 'ADMIN');
CREATE TYPE "Currency" AS ENUM ('EGP', 'USD');
CREATE TYPE "OrderSide" AS ENUM ('BUY', 'SELL');
CREATE TYPE "OrderType" AS ENUM ('MARKET', 'LIMIT');
CREATE TYPE "OrderValidity" AS ENUM ('DAY', 'GTC', 'GTD');
CREATE TYPE "ExecutionRule" AS ENUM ('REGULAR', 'MF', 'FOK', 'FAK', 'AON');
CREATE TYPE "OrderStatus" AS ENUM ('PENDING', 'PARTIALLY_FILLED', 'EXECUTED', 'CANCELLED');
CREATE TYPE "TransferType" AS ENUM ('DEPOSIT', 'WITHDRAWAL');
CREATE TYPE "TransferStatus" AS ENUM ('PENDING', 'COMPLETED', 'FAILED');
CREATE TYPE "PaymentProvider" AS ENUM ('PAYMOB', 'PAYTABS', 'MANUAL');
CREATE TYPE "AlertCondition" AS ENUM ('RISES_ABOVE', 'FALLS_BELOW');
CREATE TYPE "LedgerEntryType" AS ENUM ('DEPOSIT', 'WITHDRAWAL_HOLD', 'WITHDRAWAL_RELEASE', 'WITHDRAWAL_SETTLED', 'BUY_SETTLEMENT', 'SELL_SETTLEMENT', 'FEE');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" VARCHAR(254) NOT NULL,
    "password_hash" TEXT NOT NULL,
    "full_name_ar" VARCHAR(120) NOT NULL,
    "full_name_en" VARCHAR(120) NOT NULL,
    "unified_id" VARCHAR(32) NOT NULL DEFAULT ('EGX-'::text || (nextval('unified_id_seq'::regclass))::text),
    "role" "Role" NOT NULL DEFAULT 'TRADER',
    "password_changed_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stocks" (
    "symbol" VARCHAR(16) NOT NULL,
    "name_ar" VARCHAR(160) NOT NULL,
    "name_en" VARCHAR(160) NOT NULL,
    "sector_ar" VARCHAR(120) NOT NULL,
    "sector_en" VARCHAR(120) NOT NULL,
    "current_price" DECIMAL(18,4) NOT NULL,
    "previous_close" DECIMAL(18,4) NOT NULL,
    "open_price" DECIMAL(18,4) NOT NULL,
    "day_high" DECIMAL(18,4) NOT NULL,
    "day_low" DECIMAL(18,4) NOT NULL,
    "volume" BIGINT NOT NULL DEFAULT 0,
    "is_sharia_compliant" BOOLEAN NOT NULL DEFAULT false,
    "currency" "Currency" NOT NULL DEFAULT 'EGP',
    "pe_ratio" DECIMAL(12,4),
    "week_52_high" DECIMAL(18,4),
    "week_52_low" DECIMAL(18,4),
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "stocks_pkey" PRIMARY KEY ("symbol")
);

-- CreateTable
CREATE TABLE "portfolios" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "currency" "Currency" NOT NULL,
    "cash_balance" DECIMAL(20,4) NOT NULL DEFAULT 0,
    "buying_power" DECIMAL(20,4) NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "portfolios_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "holdings" (
    "id" UUID NOT NULL,
    "portfolio_id" UUID NOT NULL,
    "symbol" VARCHAR(16) NOT NULL,
    "quantity" INTEGER NOT NULL,
    "reserved_quantity" INTEGER NOT NULL DEFAULT 0,
    "average_buy_price" DECIMAL(18,4) NOT NULL,

    CONSTRAINT "holdings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "orders" (
    "id" VARCHAR(32) NOT NULL DEFAULT ('ORD-'::text || (nextval('order_id_seq'::regclass))::text),
    "user_id" UUID NOT NULL,
    "portfolio_id" UUID NOT NULL,
    "symbol" VARCHAR(16) NOT NULL,
    "side" "OrderSide" NOT NULL,
    "type" "OrderType" NOT NULL,
    "target_price" DECIMAL(18,4),
    "quantity" INTEGER NOT NULL,
    "filled_quantity" INTEGER NOT NULL DEFAULT 0,
    "minimum_block_quantity" INTEGER,
    "validity" "OrderValidity" NOT NULL DEFAULT 'DAY',
    "valid_until_date" DATE,
    "execution_rule" "ExecutionRule" NOT NULL DEFAULT 'REGULAR',
    "custodian_bank" VARCHAR(80) NOT NULL,
    "currency" "Currency" NOT NULL,
    "status" "OrderStatus" NOT NULL DEFAULT 'PENDING',
    "locked_amount" DECIMAL(20,4) NOT NULL DEFAULT 0,
    "average_fill_price" DECIMAL(18,4),
    "cancel_reason" VARCHAR(200),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trades" (
    "id" UUID NOT NULL,
    "order_id" VARCHAR(32) NOT NULL,
    "user_id" UUID NOT NULL,
    "symbol" VARCHAR(16) NOT NULL,
    "side" "OrderSide" NOT NULL,
    "quantity" INTEGER NOT NULL,
    "price" DECIMAL(18,4) NOT NULL,
    "fee" DECIMAL(20,4) NOT NULL DEFAULT 0,
    "executed_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "trades_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transfers" (
    "id" VARCHAR(32) NOT NULL DEFAULT ('TRF-'::text || (nextval('transfer_id_seq'::regclass))::text),
    "user_id" UUID NOT NULL,
    "portfolio_id" UUID NOT NULL,
    "amount" DECIMAL(20,4) NOT NULL,
    "currency" "Currency" NOT NULL,
    "type" "TransferType" NOT NULL,
    "method" VARCHAR(40) NOT NULL,
    "destination" VARCHAR(64),
    "provider" "PaymentProvider",
    "provider_ref" VARCHAR(128),
    "status" "TransferStatus" NOT NULL DEFAULT 'PENDING',
    "failure_reason" VARCHAR(200),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "transfers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ledger_entries" (
    "id" UUID NOT NULL,
    "portfolio_id" UUID NOT NULL,
    "type" "LedgerEntryType" NOT NULL,
    "cash_delta" DECIMAL(20,4) NOT NULL,
    "buying_power_delta" DECIMAL(20,4) NOT NULL,
    "cash_balance_after" DECIMAL(20,4) NOT NULL,
    "ref_id" VARCHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ledger_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "price_alerts" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "symbol" VARCHAR(16) NOT NULL,
    "target_price" DECIMAL(18,4) NOT NULL,
    "condition" "AlertCondition" NOT NULL,
    "is_triggered" BOOLEAN NOT NULL DEFAULT false,
    "triggered_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "price_alerts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token_hash" CHAR(64) NOT NULL,
    "family_id" UUID NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "revoked_at" TIMESTAMPTZ(3),
    "rotated_at" TIMESTAMPTZ(3),
    "user_agent" VARCHAR(255),
    "ip" VARCHAR(64),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_events" (
    "id" UUID NOT NULL,
    "provider" "PaymentProvider" NOT NULL,
    "event_key" VARCHAR(128) NOT NULL,
    "transfer_id" VARCHAR(32),
    "payload" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payment_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");
CREATE UNIQUE INDEX "users_unified_id_key" ON "users"("unified_id");
CREATE INDEX "stocks_sector_en_idx" ON "stocks"("sector_en");
CREATE UNIQUE INDEX "portfolios_user_id_currency_key" ON "portfolios"("user_id", "currency");
CREATE UNIQUE INDEX "holdings_portfolio_id_symbol_key" ON "holdings"("portfolio_id", "symbol");
CREATE INDEX "orders_user_id_created_at_idx" ON "orders"("user_id", "created_at" DESC);
CREATE INDEX "orders_symbol_status_idx" ON "orders"("symbol", "status");
CREATE INDEX "orders_status_validity_idx" ON "orders"("status", "validity");
CREATE INDEX "trades_symbol_executed_at_idx" ON "trades"("symbol", "executed_at" DESC);
CREATE INDEX "trades_user_id_executed_at_idx" ON "trades"("user_id", "executed_at" DESC);
CREATE UNIQUE INDEX "transfers_provider_ref_key" ON "transfers"("provider_ref");
CREATE INDEX "transfers_user_id_created_at_idx" ON "transfers"("user_id", "created_at" DESC);
CREATE INDEX "ledger_entries_portfolio_id_created_at_idx" ON "ledger_entries"("portfolio_id", "created_at" DESC);
CREATE INDEX "price_alerts_symbol_is_triggered_idx" ON "price_alerts"("symbol", "is_triggered");
CREATE INDEX "price_alerts_user_id_idx" ON "price_alerts"("user_id");
CREATE UNIQUE INDEX "refresh_tokens_token_hash_key" ON "refresh_tokens"("token_hash");
CREATE INDEX "refresh_tokens_user_id_idx" ON "refresh_tokens"("user_id");
CREATE INDEX "refresh_tokens_family_id_idx" ON "refresh_tokens"("family_id");
CREATE UNIQUE INDEX "payment_events_provider_event_key_key" ON "payment_events"("provider", "event_key");

-- AddForeignKey
ALTER TABLE "portfolios" ADD CONSTRAINT "portfolios_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "holdings" ADD CONSTRAINT "holdings_portfolio_id_fkey" FOREIGN KEY ("portfolio_id") REFERENCES "portfolios"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "holdings" ADD CONSTRAINT "holdings_symbol_fkey" FOREIGN KEY ("symbol") REFERENCES "stocks"("symbol") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "orders" ADD CONSTRAINT "orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "orders" ADD CONSTRAINT "orders_portfolio_id_fkey" FOREIGN KEY ("portfolio_id") REFERENCES "portfolios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "orders" ADD CONSTRAINT "orders_symbol_fkey" FOREIGN KEY ("symbol") REFERENCES "stocks"("symbol") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "trades" ADD CONSTRAINT "trades_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "trades" ADD CONSTRAINT "trades_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "trades" ADD CONSTRAINT "trades_symbol_fkey" FOREIGN KEY ("symbol") REFERENCES "stocks"("symbol") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_portfolio_id_fkey" FOREIGN KEY ("portfolio_id") REFERENCES "portfolios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_portfolio_id_fkey" FOREIGN KEY ("portfolio_id") REFERENCES "portfolios"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "price_alerts" ADD CONSTRAINT "price_alerts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "price_alerts" ADD CONSTRAINT "price_alerts_symbol_fkey" FOREIGN KEY ("symbol") REFERENCES "stocks"("symbol") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ---------------------------------------------------------------------------
-- Financial invariants enforced by the database itself (defence in depth:
-- even a buggy code path cannot overdraw a wallet or oversell shares).
-- ---------------------------------------------------------------------------
ALTER TABLE "portfolios" ADD CONSTRAINT "portfolios_cash_non_negative" CHECK ("cash_balance" >= 0);
ALTER TABLE "portfolios" ADD CONSTRAINT "portfolios_bp_non_negative" CHECK ("buying_power" >= 0);
ALTER TABLE "portfolios" ADD CONSTRAINT "portfolios_bp_le_cash" CHECK ("buying_power" <= "cash_balance");

ALTER TABLE "holdings" ADD CONSTRAINT "holdings_qty_non_negative" CHECK ("quantity" >= 0);
ALTER TABLE "holdings" ADD CONSTRAINT "holdings_reserved_valid" CHECK ("reserved_quantity" >= 0 AND "reserved_quantity" <= "quantity");

ALTER TABLE "orders" ADD CONSTRAINT "orders_qty_positive" CHECK ("quantity" > 0);
ALTER TABLE "orders" ADD CONSTRAINT "orders_filled_valid" CHECK ("filled_quantity" >= 0 AND "filled_quantity" <= "quantity");
ALTER TABLE "orders" ADD CONSTRAINT "orders_locked_non_negative" CHECK ("locked_amount" >= 0);
ALTER TABLE "orders" ADD CONSTRAINT "orders_limit_price" CHECK (("type" = 'LIMIT' AND "target_price" IS NOT NULL AND "target_price" > 0) OR ("type" = 'MARKET' AND "target_price" IS NULL));
ALTER TABLE "orders" ADD CONSTRAINT "orders_min_block_valid" CHECK ("minimum_block_quantity" IS NULL OR ("minimum_block_quantity" > 0 AND "minimum_block_quantity" <= "quantity"));
ALTER TABLE "orders" ADD CONSTRAINT "orders_gtd_date" CHECK (("validity" = 'GTD') = ("valid_until_date" IS NOT NULL));

ALTER TABLE "trades" ADD CONSTRAINT "trades_qty_positive" CHECK ("quantity" > 0 AND "price" > 0);
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_amount_positive" CHECK ("amount" > 0);
ALTER TABLE "price_alerts" ADD CONSTRAINT "price_alerts_target_positive" CHECK ("target_price" > 0);
ALTER TABLE "stocks" ADD CONSTRAINT "stocks_prices_positive" CHECK ("current_price" > 0 AND "previous_close" > 0);
