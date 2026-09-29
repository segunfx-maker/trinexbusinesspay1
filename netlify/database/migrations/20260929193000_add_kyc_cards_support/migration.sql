CREATE TABLE "kyc_submissions" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "customer_id" uuid NOT NULL UNIQUE REFERENCES "users"("id"),
  "legal_name" text NOT NULL, "date_of_birth" date NOT NULL, "country" text NOT NULL, "address" text NOT NULL,
  "phone" text NOT NULL, "identification_type" text NOT NULL, "identification_number" text NOT NULL,
  "document_reference" text NOT NULL, "supporting_references" text,
  "status" text NOT NULL DEFAULT 'SUBMITTED' CHECK ("status" IN ('SUBMITTED','UNDER_REVIEW','APPROVED','REJECTED','MORE_INFORMATION_REQUIRED')),
  "review_notes" text, "reviewed_by" text, "created_at" timestamptz NOT NULL DEFAULT now(), "updated_at" timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX "kyc_status_idx" ON "kyc_submissions" ("status", "updated_at");
CREATE TABLE "card_requests" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "request_id" text NOT NULL UNIQUE,
  "customer_id" uuid NOT NULL REFERENCES "users"("id"), "status" text NOT NULL DEFAULT 'REQUESTED' CHECK ("status" IN ('REQUESTED','PENDING','ACTIVE','FROZEN','CANCELLED','REJECTED')),
  "card_label" text NOT NULL, "idempotency_key" text NOT NULL UNIQUE, "review_notes" text, "reviewed_by" text,
  "created_at" timestamptz NOT NULL DEFAULT now(), "updated_at" timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX "card_requests_customer_idx" ON "card_requests" ("customer_id", "created_at");
