CREATE TABLE "investment_audit_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"investment_id" uuid NOT NULL,
	"activity_id" text NOT NULL UNIQUE,
	"admin_user_id" text,
	"admin_role" text,
	"action" text NOT NULL,
	"previous_status" text,
	"new_status" text,
	"previous_value" text,
	"new_value" text,
	"reason" text,
	"metadata" text DEFAULT '{}' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "investment_plans" (
	"id" text PRIMARY KEY,
	"name" text NOT NULL UNIQUE,
	"description" text NOT NULL,
	"minimum_amount" numeric(24,8) NOT NULL,
	"maximum_amount" numeric(24,8) NOT NULL,
	"currency" text DEFAULT 'USD' NOT NULL,
	"duration" text NOT NULL,
	"return_information" text NOT NULL,
	"risk_information" text NOT NULL,
	"status" text DEFAULT 'ACTIVE' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "investment_requests" ADD COLUMN "customer_note" text;--> statement-breakpoint
ALTER TABLE "investment_requests" ADD COLUMN "customer_visible_note" text;--> statement-breakpoint
ALTER TABLE "investment_requests" ADD COLUMN "product_name" text;--> statement-breakpoint
ALTER TABLE "investment_requests" ADD COLUMN "reference_number" text;--> statement-breakpoint
ALTER TABLE "investment_requests" ADD COLUMN "supporting_reference" text;--> statement-breakpoint
ALTER TABLE "investment_requests" ADD COLUMN "initial_value" numeric(24,8);--> statement-breakpoint
ALTER TABLE "investment_requests" ADD COLUMN "current_value" numeric(24,8);--> statement-breakpoint
ALTER TABLE "investment_requests" ADD COLUMN "return_amount" numeric(24,8);--> statement-breakpoint
ALTER TABLE "investment_requests" ADD COLUMN "return_percentage" numeric(12,6);--> statement-breakpoint
ALTER TABLE "investment_requests" ADD COLUMN "start_date" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "investment_requests" ADD COLUMN "maturity_date" timestamp with time zone;--> statement-breakpoint
CREATE INDEX "investment_audit_investment_idx" ON "investment_audit_logs" ("investment_id","created_at");--> statement-breakpoint
ALTER TABLE "investment_audit_logs" ADD CONSTRAINT "investment_audit_logs_investment_id_investment_requests_id_fkey" FOREIGN KEY ("investment_id") REFERENCES "investment_requests"("id");
--> statement-breakpoint
INSERT INTO "investment_plans" ("id","name","description","minimum_amount","maximum_amount","currency","duration","return_information","risk_information","status") VALUES
('STARTER','Starter','A lower-minimum request for manual suitability and product review.',500,4999.99,'USD','Confirmed during review','No return projection is published. Illustrative example — not guaranteed.','Investment value may fall and capital may be lost.','ACTIVE'),
('GROWTH','Growth','A manually reviewed request intended for customers considering a longer investment horizon.',5000,9999.99,'USD','Confirmed during review','No return projection is published. Illustrative example — not guaranteed.','Investment value may fall and liquidity can be limited.','ACTIVE'),
('PREMIUM','Premium','A higher-value request subject to manual product, risk, and suitability review.',10000,24999.99,'USD','Confirmed during review','No return projection is published. Illustrative example — not guaranteed.','Higher-value investments may involve material loss.','ACTIVE'),
('DIAMOND','Diamond','An individually reviewed investment request with terms disclosed before activation.',25000,99999.99,'USD','Confirmed during review','No return projection is published. Illustrative example — not guaranteed.','Product-specific risks are disclosed before approval.','ACTIVE'),
('BUSINESS','Business','A business investment request requiring operational and compliance review.',100000,1000000000,'USD','Confirmed during review','No return projection is published. Illustrative example — not guaranteed.','Business investments can lose value and may be illiquid.','ACTIVE');
