CREATE TYPE "investment_order_status" AS ENUM('PENDING', 'SUBMITTED', 'EXECUTION_PENDING', 'EXECUTED', 'FAILED', 'CANCELED');--> statement-breakpoint
CREATE TYPE "investment_request_status" AS ENUM('REQUESTED', 'UNDER_REVIEW', 'APPROVED', 'EXECUTION_PENDING', 'EXECUTED', 'FAILED', 'REJECTED', 'CANCELED');--> statement-breakpoint
CREATE TYPE "investment_transaction_type" AS ENUM('CASH_DEPOSIT', 'CASH_WITHDRAWAL', 'BUY', 'SELL', 'FEE', 'DIVIDEND');--> statement-breakpoint
CREATE TABLE "investment_accounts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"customer_id" uuid NOT NULL,
	"currency" text DEFAULT 'USD' NOT NULL,
	"status" text DEFAULT 'MANUAL_PROCESSING' NOT NULL,
	"provider_account_reference" text,
	"environment" "environment" DEFAULT 'SANDBOX'::"environment" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "investment_holdings" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"account_id" uuid NOT NULL,
	"asset_name" text NOT NULL,
	"asset_symbol" text NOT NULL,
	"asset_type" text NOT NULL,
	"quantity" numeric(30,12) NOT NULL,
	"average_purchase_price" numeric(24,8) NOT NULL,
	"currency" text NOT NULL,
	"provider_reference" text NOT NULL,
	"acquired_at" timestamp with time zone NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "investment_orders" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"order_id" text NOT NULL UNIQUE,
	"request_id" uuid NOT NULL,
	"account_id" uuid NOT NULL,
	"side" text DEFAULT 'BUY' NOT NULL,
	"status" "investment_order_status" DEFAULT 'PENDING'::"investment_order_status" NOT NULL,
	"requested_amount" numeric(24,8) NOT NULL,
	"executed_quantity" numeric(30,12),
	"executed_price" numeric(24,8),
	"provider_reference" text,
	"submitted_at" timestamp with time zone,
	"executed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "investment_prices" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"asset_symbol" text NOT NULL,
	"asset_name" text NOT NULL,
	"asset_type" text NOT NULL,
	"price" numeric(24,8) NOT NULL,
	"currency" text NOT NULL,
	"provider_name" text NOT NULL,
	"provider_reference" text NOT NULL,
	"priced_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "investment_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"request_id" text NOT NULL UNIQUE,
	"activity_id" text NOT NULL UNIQUE,
	"account_id" uuid NOT NULL,
	"asset_name" text NOT NULL,
	"asset_symbol" text,
	"asset_type" text NOT NULL,
	"amount" numeric(24,8) NOT NULL,
	"currency" text NOT NULL,
	"status" "investment_request_status" DEFAULT 'REQUESTED'::"investment_request_status" NOT NULL,
	"idempotency_key" text NOT NULL UNIQUE,
	"security_verified_at" timestamp with time zone NOT NULL,
	"assigned_admin_identity_id" text,
	"admin_notes" text,
	"provider_reference" text,
	"environment" "environment" DEFAULT 'SANDBOX'::"environment" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "investment_transactions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"transaction_id" text NOT NULL UNIQUE,
	"activity_id" text NOT NULL UNIQUE,
	"account_id" uuid NOT NULL,
	"order_id" uuid,
	"type" "investment_transaction_type" NOT NULL,
	"amount" numeric(24,8) NOT NULL,
	"quantity" numeric(30,12),
	"price" numeric(24,8),
	"currency" text NOT NULL,
	"provider_reference" text NOT NULL,
	"occurred_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX "investment_accounts_customer_currency_env" ON "investment_accounts" ("customer_id","currency","environment");--> statement-breakpoint
CREATE UNIQUE INDEX "investment_holdings_account_asset" ON "investment_holdings" ("account_id","asset_symbol");--> statement-breakpoint
CREATE INDEX "investment_holdings_account_idx" ON "investment_holdings" ("account_id");--> statement-breakpoint
CREATE INDEX "investment_orders_request_idx" ON "investment_orders" ("request_id");--> statement-breakpoint
CREATE INDEX "investment_orders_account_idx" ON "investment_orders" ("account_id");--> statement-breakpoint
CREATE INDEX "investment_prices_asset_time_idx" ON "investment_prices" ("asset_symbol","priced_at");--> statement-breakpoint
CREATE INDEX "investment_requests_account_idx" ON "investment_requests" ("account_id");--> statement-breakpoint
CREATE INDEX "investment_requests_queue_idx" ON "investment_requests" ("status","created_at");--> statement-breakpoint
CREATE INDEX "investment_transactions_account_idx" ON "investment_transactions" ("account_id");--> statement-breakpoint
CREATE INDEX "investment_transactions_order_idx" ON "investment_transactions" ("order_id");--> statement-breakpoint
ALTER TABLE "investment_accounts" ADD CONSTRAINT "investment_accounts_customer_id_users_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "users"("id");--> statement-breakpoint
ALTER TABLE "investment_holdings" ADD CONSTRAINT "investment_holdings_account_id_investment_accounts_id_fkey" FOREIGN KEY ("account_id") REFERENCES "investment_accounts"("id");--> statement-breakpoint
ALTER TABLE "investment_orders" ADD CONSTRAINT "investment_orders_request_id_investment_requests_id_fkey" FOREIGN KEY ("request_id") REFERENCES "investment_requests"("id");--> statement-breakpoint
ALTER TABLE "investment_orders" ADD CONSTRAINT "investment_orders_account_id_investment_accounts_id_fkey" FOREIGN KEY ("account_id") REFERENCES "investment_accounts"("id");--> statement-breakpoint
ALTER TABLE "investment_requests" ADD CONSTRAINT "investment_requests_account_id_investment_accounts_id_fkey" FOREIGN KEY ("account_id") REFERENCES "investment_accounts"("id");--> statement-breakpoint
ALTER TABLE "investment_transactions" ADD CONSTRAINT "investment_transactions_account_id_investment_accounts_id_fkey" FOREIGN KEY ("account_id") REFERENCES "investment_accounts"("id");--> statement-breakpoint
ALTER TABLE "investment_transactions" ADD CONSTRAINT "investment_transactions_order_id_investment_orders_id_fkey" FOREIGN KEY ("order_id") REFERENCES "investment_orders"("id");