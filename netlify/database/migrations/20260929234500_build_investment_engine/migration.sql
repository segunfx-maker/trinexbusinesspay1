CREATE TYPE investment_position_status AS ENUM ('PENDING','ACTIVE','PAUSED','COMPLETED','CANCELLED');
CREATE TYPE investment_asset_type AS ENUM ('FIAT','CRYPTO');

ALTER TABLE investment_plans ADD COLUMN configured_monthly_rate numeric(12,4) NOT NULL DEFAULT 0;
ALTER TABLE investment_plans ADD COLUMN maximum_unlimited boolean NOT NULL DEFAULT false;
ALTER TABLE investment_plans ADD COLUMN calculation_method text NOT NULL DEFAULT 'PRINCIPAL_PERCENTAGE';
ALTER TABLE investment_plans ADD COLUMN version integer NOT NULL DEFAULT 1;
DELETE FROM investment_plans;
ALTER TABLE investment_plans DROP CONSTRAINT IF EXISTS investment_plans_name_key;
INSERT INTO investment_plans(id,name,description,minimum_amount,maximum_amount,maximum_unlimited,currency,duration,return_information,risk_information,status,configured_monthly_rate)
VALUES
 ('GOLD','Gold','Core configurable investment plan.',5000,20000,false,'MULTI_ASSET','Open-ended','Configured Monthly Performance: 1000%. This is an internal calculation parameter, not a guaranteed return.','Capital is at risk. This product does not represent brokerage custody, securities ownership, or guaranteed real-world profit.','ACTIVE',1000),
 ('DIAMOND','Diamond','Advanced configurable investment plan.',21000,100000,false,'MULTI_ASSET','Open-ended','Configured Monthly Performance: 2500%. This is an internal calculation parameter, not a guaranteed return.','Capital is at risk. This product does not represent brokerage custody, securities ownership, or guaranteed real-world profit.','ACTIVE',2500),
 ('PLATINUM','Platinum','Premier configurable investment plan.',110000,9999999999999999,true,'MULTI_ASSET','Open-ended','Configured Monthly Performance: 4000%. This is an internal calculation parameter, not a guaranteed return.','Capital is at risk. This product does not represent brokerage custody, securities ownership, or guaranteed real-world profit.','ACTIVE',4000);

CREATE TABLE investment_positions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investment_id text NOT NULL UNIQUE,
  customer_id uuid NOT NULL REFERENCES users(id),
  plan_id text NOT NULL REFERENCES investment_plans(id),
  plan_name text NOT NULL,
  funding_asset text NOT NULL CHECK (funding_asset IN ('USD','EUR','GBP','BTC','ETH')),
  funding_asset_type investment_asset_type NOT NULL,
  funding_account_id uuid NOT NULL REFERENCES accounts(id),
  principal_amount numeric(30,12) NOT NULL CHECK (principal_amount > 0),
  configured_monthly_rate numeric(12,4) NOT NULL CHECK (configured_monthly_rate >= 0),
  current_performance numeric(30,12) NOT NULL DEFAULT 0,
  current_value numeric(30,12) NOT NULL,
  status investment_position_status NOT NULL DEFAULT 'PENDING',
  start_date timestamptz NOT NULL,
  next_performance_date timestamptz NOT NULL,
  maturity_date timestamptz,
  funding_ledger_transaction_id uuid NOT NULL REFERENCES transactions(id),
  activity_id text NOT NULL UNIQUE,
  idempotency_key text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX investment_positions_customer_created_idx ON investment_positions(customer_id,created_at DESC);
CREATE INDEX investment_positions_status_next_idx ON investment_positions(status,next_performance_date);

CREATE TABLE investment_engine_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id text NOT NULL UNIQUE,
  investment_id uuid NOT NULL REFERENCES investment_positions(id),
  customer_id uuid NOT NULL REFERENCES users(id),
  type text NOT NULL CHECK (type IN ('INVESTMENT_CREATED','INVESTMENT_FUNDING','INVESTMENT_PERFORMANCE','INVESTMENT_COMPLETED','INVESTMENT_CANCELLED')),
  asset text NOT NULL CHECK (asset IN ('USD','EUR','GBP','BTC','ETH')),
  amount numeric(30,12) NOT NULL CHECK (amount >= 0),
  status text NOT NULL,
  description text NOT NULL,
  ledger_transaction_id uuid REFERENCES transactions(id),
  activity_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX investment_engine_transactions_customer_idx ON investment_engine_transactions(customer_id,created_at DESC);

CREATE TABLE investment_performance_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investment_id uuid NOT NULL REFERENCES investment_positions(id),
  customer_id uuid NOT NULL REFERENCES users(id),
  asset text NOT NULL,
  amount numeric(30,12) NOT NULL CHECK (amount >= 0),
  calculation_period_start timestamptz NOT NULL,
  calculation_period_end timestamptz NOT NULL,
  rate_used numeric(12,4) NOT NULL,
  calculation_method text NOT NULL,
  ledger_transaction_id uuid NOT NULL REFERENCES transactions(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(investment_id,calculation_period_start,calculation_period_end)
);

CREATE TABLE investment_plan_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id text NOT NULL REFERENCES investment_plans(id),
  admin_identity_id text NOT NULL,
  before_value text NOT NULL,
  after_value text NOT NULL,
  reason text NOT NULL,
  activity_id text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION prevent_investment_posting_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.funding_ledger_transaction_id IS DISTINCT FROM OLD.funding_ledger_transaction_id OR NEW.customer_id IS DISTINCT FROM OLD.customer_id OR NEW.funding_asset IS DISTINCT FROM OLD.funding_asset OR NEW.principal_amount IS DISTINCT FROM OLD.principal_amount THEN
    RAISE EXCEPTION 'Posted investment funding is immutable';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER investment_positions_protect_posting BEFORE UPDATE ON investment_positions FOR EACH ROW EXECUTE FUNCTION prevent_investment_posting_mutation();
