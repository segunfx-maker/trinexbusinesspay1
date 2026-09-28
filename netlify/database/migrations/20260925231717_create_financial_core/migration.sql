CREATE TYPE "entry_direction" AS ENUM('DEBIT', 'CREDIT');--> statement-breakpoint
CREATE TYPE "environment" AS ENUM('SANDBOX', 'PRODUCTION');--> statement-breakpoint
CREATE TYPE "gate_state" AS ENUM('SANDBOX', 'PROVIDER_NOT_CONNECTED', 'READY_FOR_PRODUCTION', 'PRODUCTION_ENABLED');--> statement-breakpoint
CREATE TYPE "transfer_status" AS ENUM('DRAFT', 'SUBMITTED', 'SECURITY_REVIEW', 'PENDING', 'UNDER_REVIEW', 'APPROVED', 'PROCESSING', 'SENT', 'SETTLED', 'COMPLETED', 'FAILED', 'REJECTED', 'CANCELED', 'RETURNED', 'NEEDS_INFORMATION');--> statement-breakpoint
CREATE TYPE "transfer_type" AS ENUM('INTERNAL', 'BANK', 'WIRE');--> statement-breakpoint
CREATE TABLE "accounts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"user_id" uuid NOT NULL,
	"currency" text NOT NULL,
	"environment" "environment" DEFAULT 'SANDBOX'::"environment" NOT NULL,
	"status" text DEFAULT 'ACTIVE' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "audit_events" (
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
CREATE TABLE "beneficiaries" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"owner_id" uuid NOT NULL,
	"full_name" text NOT NULL,
	"bank_name" text NOT NULL,
	"country" text NOT NULL,
	"currency" text NOT NULL,
	"account_identifier_masked" text NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "ledger_accounts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"account_id" uuid NOT NULL,
	"code" text NOT NULL UNIQUE,
	"currency" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "ledger_entries" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"transaction_id" uuid NOT NULL,
	"ledger_account_id" uuid NOT NULL,
	"direction" "entry_direction" NOT NULL,
	"amount" numeric(24,8) NOT NULL,
	"currency" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notifications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"user_id" uuid NOT NULL,
	"activity_id" text NOT NULL,
	"category" text NOT NULL,
	"title" text NOT NULL,
	"body" text NOT NULL,
	"read" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "production_gates" (
	"service" text PRIMARY KEY,
	"state" "gate_state" DEFAULT 'PROVIDER_NOT_CONNECTED'::"gate_state" NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "transactions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"transaction_id" text NOT NULL UNIQUE,
	"activity_id" text NOT NULL UNIQUE,
	"idempotency_key" text NOT NULL UNIQUE,
	"currency" text NOT NULL,
	"amount" numeric(24,8) NOT NULL,
	"status" "transfer_status" NOT NULL,
	"environment" "environment" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "transfers" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"transaction_id" uuid NOT NULL,
	"sender_account_id" uuid NOT NULL,
	"recipient_account_id" uuid,
	"type" "transfer_type" NOT NULL,
	"status" "transfer_status" NOT NULL,
	"amount" numeric(24,8) NOT NULL,
	"fee" numeric(24,8) DEFAULT '0' NOT NULL,
	"currency" text NOT NULL,
	"note" text,
	"provider_reference" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"identity_id" text NOT NULL UNIQUE,
	"email" text NOT NULL UNIQUE,
	"username" text NOT NULL UNIQUE,
	"trinex_id" text NOT NULL UNIQUE,
	"full_name" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX "accounts_user_currency_env" ON "accounts" ("user_id","currency","environment");--> statement-breakpoint
CREATE INDEX "audit_activity_idx" ON "audit_events" ("activity_id");--> statement-breakpoint
CREATE INDEX "entries_transaction_idx" ON "ledger_entries" ("transaction_id");--> statement-breakpoint
CREATE INDEX "entries_account_idx" ON "ledger_entries" ("ledger_account_id");--> statement-breakpoint
CREATE INDEX "transfers_sender_idx" ON "transfers" ("sender_account_id");--> statement-breakpoint
CREATE INDEX "transfers_recipient_idx" ON "transfers" ("recipient_account_id");--> statement-breakpoint
ALTER TABLE "accounts" ADD CONSTRAINT "accounts_user_id_users_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id");--> statement-breakpoint
ALTER TABLE "beneficiaries" ADD CONSTRAINT "beneficiaries_owner_id_users_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id");--> statement-breakpoint
ALTER TABLE "ledger_accounts" ADD CONSTRAINT "ledger_accounts_account_id_accounts_id_fkey" FOREIGN KEY ("account_id") REFERENCES "accounts"("id");--> statement-breakpoint
ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_transaction_id_transactions_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "transactions"("id");--> statement-breakpoint
ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_ledger_account_id_ledger_accounts_id_fkey" FOREIGN KEY ("ledger_account_id") REFERENCES "ledger_accounts"("id");--> statement-breakpoint
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_users_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id");--> statement-breakpoint
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_transaction_id_transactions_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "transactions"("id");--> statement-breakpoint
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_sender_account_id_accounts_id_fkey" FOREIGN KEY ("sender_account_id") REFERENCES "accounts"("id");--> statement-breakpoint
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_recipient_account_id_accounts_id_fkey" FOREIGN KEY ("recipient_account_id") REFERENCES "accounts"("id");