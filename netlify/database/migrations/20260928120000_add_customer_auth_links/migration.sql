CREATE TABLE "customer_auth_identities" (
	"provider" text NOT NULL,
	"provider_subject" text NOT NULL,
	"customer_id" uuid NOT NULL,
	"provider_email" text,
	"email_is_private_relay" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_login_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "customer_auth_identities_provider_subject_pk" PRIMARY KEY("provider", "provider_subject")
);
--> statement-breakpoint
CREATE INDEX "customer_auth_identities_customer_idx" ON "customer_auth_identities" ("customer_id");
--> statement-breakpoint
ALTER TABLE "customer_auth_identities" ADD CONSTRAINT "customer_auth_identities_customer_id_users_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "users"("id") ON DELETE CASCADE;

