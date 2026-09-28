CREATE TYPE "crypto_withdrawal_status" AS ENUM('WITHDRAWAL_REQUESTED', 'UNDER_REVIEW', 'APPROVED', 'PROCESSING', 'BROADCAST', 'CONFIRMED', 'COMPLETED', 'REJECTED', 'FAILED', 'CANCELED');--> statement-breakpoint
CREATE TABLE "crypto_withdrawals" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"withdrawal_id" text NOT NULL UNIQUE,
	"activity_id" text NOT NULL UNIQUE,
	"user_id" uuid NOT NULL,
	"asset_id" uuid NOT NULL,
	"destination_address" text NOT NULL,
	"requested_amount" numeric(30,12) NOT NULL,
	"estimated_network_fee" numeric(30,12) NOT NULL,
	"price" numeric(24,8) NOT NULL,
	"estimated_usd" numeric(24,8) NOT NULL,
	"status" "crypto_withdrawal_status" DEFAULT 'WITHDRAWAL_REQUESTED'::"crypto_withdrawal_status" NOT NULL,
	"idempotency_key" text NOT NULL UNIQUE,
	"security_verified_at" timestamp with time zone NOT NULL,
	"actual_amount" numeric(30,12),
	"actual_network_fee" numeric(30,12),
	"transaction_hash" text UNIQUE,
	"confirmations" integer DEFAULT 0 NOT NULL,
	"required_confirmations" integer DEFAULT 3 NOT NULL,
	"broadcast_at" timestamp with time zone,
	"confirmed_at" timestamp with time zone,
	"completed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE INDEX "crypto_withdrawals_user_idx" ON "crypto_withdrawals" ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "crypto_withdrawals_status_idx" ON "crypto_withdrawals" ("status","created_at");--> statement-breakpoint
ALTER TABLE "crypto_withdrawals" ADD CONSTRAINT "crypto_withdrawals_user_id_users_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id");--> statement-breakpoint
ALTER TABLE "crypto_withdrawals" ADD CONSTRAINT "crypto_withdrawals_asset_id_crypto_assets_id_fkey" FOREIGN KEY ("asset_id") REFERENCES "crypto_assets"("id");