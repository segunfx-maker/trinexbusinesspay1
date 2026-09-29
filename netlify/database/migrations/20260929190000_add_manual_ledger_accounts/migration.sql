ALTER TABLE "accounts" ALTER COLUMN "user_id" DROP NOT NULL;
ALTER TABLE "accounts" ADD COLUMN "account_owner_type" text DEFAULT 'CUSTOMER' NOT NULL;
ALTER TABLE "accounts" ADD CONSTRAINT "accounts_owner_type_check" CHECK ("account_owner_type" IN ('CUSTOMER','SYSTEM'));
ALTER TABLE "accounts" ADD CONSTRAINT "accounts_owner_required" CHECK (("account_owner_type"='CUSTOMER' AND "user_id" IS NOT NULL) OR ("account_owner_type"='SYSTEM' AND "user_id" IS NULL));
CREATE UNIQUE INDEX "accounts_system_currency_env" ON "accounts" ("currency","environment") WHERE "account_owner_type"='SYSTEM';

