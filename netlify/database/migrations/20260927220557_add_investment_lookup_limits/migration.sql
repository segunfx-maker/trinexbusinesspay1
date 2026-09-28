CREATE TABLE "investment_lookup_limits" (
	"key_hash" text PRIMARY KEY,
	"requests" integer DEFAULT 0 NOT NULL,
	"window_started_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
