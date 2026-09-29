CREATE TABLE "admin_identities" (
	"identity_id" text PRIMARY KEY,
	"email" text NOT NULL,
	"role" text NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "admin_identities_role_check" CHECK ("role" IN ('SUPER_ADMIN','ADMIN','OPERATIONS','COMPLIANCE','SUPPORT','READ_ONLY'))
);
--> statement-breakpoint
CREATE UNIQUE INDEX "admin_identities_email_lower_idx" ON "admin_identities" (lower("email"));
