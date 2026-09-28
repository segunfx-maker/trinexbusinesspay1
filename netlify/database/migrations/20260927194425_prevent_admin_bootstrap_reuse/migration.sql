CREATE TABLE "admin_bootstrap_state" (
	"id" text PRIMARY KEY,
	"identity_id" text NOT NULL UNIQUE,
	"completed_at" timestamp with time zone DEFAULT now() NOT NULL
);
