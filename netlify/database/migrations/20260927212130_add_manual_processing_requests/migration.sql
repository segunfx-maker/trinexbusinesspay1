CREATE TABLE "financial_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"request_id" text NOT NULL UNIQUE,
	"activity_id" text NOT NULL UNIQUE,
	"customer_id" uuid NOT NULL,
	"request_type" text NOT NULL,
	"status" text NOT NULL,
	"amount" numeric(24,8),
	"currency" text,
	"details" text DEFAULT '{}' NOT NULL,
	"assigned_admin_identity_id" text,
	"notes" text,
	"external_reference" text,
	"idempotency_key" text NOT NULL UNIQUE,
	"environment" "environment" DEFAULT 'SANDBOX'::"environment" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "production_gates" ALTER COLUMN "state" SET DATA TYPE text;--> statement-breakpoint
ALTER TABLE "production_gates" ALTER COLUMN "state" DROP DEFAULT;--> statement-breakpoint
UPDATE "production_gates" SET "state" = 'MANUAL_PROCESSING' WHERE "state" = 'PROVIDER_NOT_CONNECTED';--> statement-breakpoint
DROP TYPE "gate_state";--> statement-breakpoint
CREATE TYPE "gate_state" AS ENUM('SANDBOX', 'MANUAL_PROCESSING', 'UNAVAILABLE', 'READY_FOR_PRODUCTION', 'PRODUCTION_ENABLED');--> statement-breakpoint
ALTER TABLE "production_gates" ALTER COLUMN "state" SET DATA TYPE "gate_state" USING "state"::"gate_state";--> statement-breakpoint
ALTER TABLE "production_gates" ALTER COLUMN "state" SET DEFAULT 'MANUAL_PROCESSING'::"gate_state";--> statement-breakpoint
CREATE INDEX "financial_requests_customer_idx" ON "financial_requests" ("customer_id");--> statement-breakpoint
CREATE INDEX "financial_requests_queue_idx" ON "financial_requests" ("request_type","status","created_at");--> statement-breakpoint
ALTER TABLE "financial_requests" ADD CONSTRAINT "financial_requests_customer_id_users_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "users"("id");
