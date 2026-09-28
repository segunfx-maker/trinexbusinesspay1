CREATE TYPE "crypto_order_status" AS ENUM('BUY_REQUESTED', 'SELL_REQUESTED', 'UNDER_REVIEW', 'APPROVED', 'PROCESSING', 'EXECUTED', 'REJECTED', 'FAILED', 'CANCELED');--> statement-breakpoint
CREATE TYPE "crypto_side" AS ENUM('BUY', 'SELL');--> statement-breakpoint
CREATE TABLE "audit_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"activity_id" text NOT NULL,
	"actor_identity_id" text NOT NULL,
	"action" text NOT NULL,
	"entity_type" text NOT NULL,
	"entity_id" text NOT NULL,
	"metadata" text DEFAULT '{}' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "crypto_assets" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"symbol" text NOT NULL UNIQUE,
	"name" text NOT NULL,
	"precision" integer DEFAULT 8 NOT NULL,
	"enabled" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "crypto_balances" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"user_id" uuid NOT NULL,
	"asset_id" uuid NOT NULL,
	"available" numeric(30,12) DEFAULT '0' NOT NULL,
	"reserved" numeric(30,12) DEFAULT '0' NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "crypto_orders" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"order_id" text NOT NULL UNIQUE,
	"request_id" uuid NOT NULL,
	"asset_id" uuid NOT NULL,
	"side" "crypto_side" NOT NULL,
	"input_amount" numeric(30,12) NOT NULL,
	"input_currency" text NOT NULL,
	"estimated_btc" numeric(30,12) NOT NULL,
	"estimated_usd" numeric(24,8) NOT NULL,
	"price" numeric(24,8) NOT NULL,
	"fee" numeric(24,8) NOT NULL,
	"status" "crypto_order_status" NOT NULL,
	"external_reference" text,
	"executed_btc" numeric(30,12),
	"executed_usd" numeric(24,8),
	"executed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "crypto_price_snapshots" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"asset_id" uuid NOT NULL,
	"currency" text DEFAULT 'USD' NOT NULL,
	"price" numeric(24,8) NOT NULL,
	"change_24h" numeric(12,6),
	"provider" text NOT NULL,
	"provider_timestamp" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "crypto_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"request_id" text NOT NULL UNIQUE,
	"activity_id" text NOT NULL UNIQUE,
	"user_id" uuid NOT NULL,
	"side" "crypto_side" NOT NULL,
	"status" "crypto_order_status" NOT NULL,
	"idempotency_key" text NOT NULL UNIQUE,
	"security_verified_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "crypto_transactions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"transaction_id" text NOT NULL UNIQUE,
	"activity_id" text NOT NULL,
	"order_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"side" "crypto_side" NOT NULL,
	"btc_amount" numeric(30,12) NOT NULL,
	"usd_amount" numeric(24,8) NOT NULL,
	"fee" numeric(24,8) NOT NULL,
	"price" numeric(24,8) NOT NULL,
	"external_reference" text NOT NULL,
	"occurred_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE INDEX "crypto_audit_activity_idx" ON "audit_logs" ("activity_id");--> statement-breakpoint
CREATE INDEX "crypto_audit_entity_idx" ON "audit_logs" ("entity_type","entity_id");--> statement-breakpoint
CREATE UNIQUE INDEX "crypto_balances_user_asset" ON "crypto_balances" ("user_id","asset_id");--> statement-breakpoint
CREATE INDEX "crypto_orders_request_idx" ON "crypto_orders" ("request_id");--> statement-breakpoint
CREATE INDEX "crypto_orders_status_idx" ON "crypto_orders" ("status","created_at");--> statement-breakpoint
CREATE INDEX "crypto_prices_asset_time_idx" ON "crypto_price_snapshots" ("asset_id","created_at");--> statement-breakpoint
CREATE INDEX "crypto_transactions_order_idx" ON "crypto_transactions" ("order_id");--> statement-breakpoint
CREATE INDEX "crypto_transactions_user_idx" ON "crypto_transactions" ("user_id","created_at");--> statement-breakpoint
ALTER TABLE "crypto_balances" ADD CONSTRAINT "crypto_balances_user_id_users_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id");--> statement-breakpoint
ALTER TABLE "crypto_balances" ADD CONSTRAINT "crypto_balances_asset_id_crypto_assets_id_fkey" FOREIGN KEY ("asset_id") REFERENCES "crypto_assets"("id");--> statement-breakpoint
ALTER TABLE "crypto_orders" ADD CONSTRAINT "crypto_orders_request_id_crypto_requests_id_fkey" FOREIGN KEY ("request_id") REFERENCES "crypto_requests"("id");--> statement-breakpoint
ALTER TABLE "crypto_orders" ADD CONSTRAINT "crypto_orders_asset_id_crypto_assets_id_fkey" FOREIGN KEY ("asset_id") REFERENCES "crypto_assets"("id");--> statement-breakpoint
ALTER TABLE "crypto_price_snapshots" ADD CONSTRAINT "crypto_price_snapshots_asset_id_crypto_assets_id_fkey" FOREIGN KEY ("asset_id") REFERENCES "crypto_assets"("id");--> statement-breakpoint
ALTER TABLE "crypto_requests" ADD CONSTRAINT "crypto_requests_user_id_users_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id");--> statement-breakpoint
ALTER TABLE "crypto_transactions" ADD CONSTRAINT "crypto_transactions_order_id_crypto_orders_id_fkey" FOREIGN KEY ("order_id") REFERENCES "crypto_orders"("id");--> statement-breakpoint
ALTER TABLE "crypto_transactions" ADD CONSTRAINT "crypto_transactions_user_id_users_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id");