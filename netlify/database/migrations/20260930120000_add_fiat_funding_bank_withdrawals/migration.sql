-- Internal identifiers are customer-facing aliases, never database identifiers.
ALTER TABLE accounts ADD COLUMN internal_account_number text;
UPDATE accounts SET internal_account_number = 'TRX-' || currency || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
WHERE account_owner_type='CUSTOMER' AND currency IN ('USD','EUR','GBP') AND internal_account_number IS NULL;
CREATE UNIQUE INDEX accounts_internal_account_number_unique ON accounts(internal_account_number) WHERE internal_account_number IS NOT NULL;
ALTER TABLE accounts ADD CONSTRAINT customer_fiat_internal_number_required CHECK (
  account_owner_type <> 'CUSTOMER' OR currency NOT IN ('USD','EUR','GBP') OR internal_account_number IS NOT NULL
);

CREATE OR REPLACE FUNCTION assign_internal_account_number() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.account_owner_type='CUSTOMER' AND NEW.currency IN ('USD','EUR','GBP') AND NEW.internal_account_number IS NULL THEN
    NEW.internal_account_number := 'TRX-' || NEW.currency || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER accounts_assign_internal_number BEFORE INSERT ON accounts FOR EACH ROW EXECUTE FUNCTION assign_internal_account_number();

ALTER TABLE crypto_deposits ADD COLUMN destination_account_id uuid REFERENCES accounts(id);
ALTER TABLE crypto_deposits ADD COLUMN market_price numeric(30,12);
ALTER TABLE crypto_deposits ADD COLUMN valuation_currency text CHECK (valuation_currency IN ('USD','EUR','GBP'));
ALTER TABLE crypto_deposits ADD COLUMN valuation_amount numeric(24,8);
ALTER TABLE crypto_deposits ADD COLUMN price_timestamp timestamptz;
ALTER TABLE crypto_deposits ADD COLUMN price_source text;
ALTER TABLE crypto_deposits ADD COLUMN blockchain_verified_at timestamptz;
ALTER TABLE crypto_deposits ADD COLUMN approved_by text;
ALTER TABLE crypto_deposits ALTER COLUMN status DROP DEFAULT;
ALTER TABLE crypto_deposits ALTER COLUMN status TYPE text USING status::text;
ALTER TABLE crypto_deposits ALTER COLUMN status SET DEFAULT 'PENDING';
UPDATE crypto_deposits SET status=CASE status WHEN 'PENDING_REVIEW' THEN 'PENDING' WHEN 'MANUALLY_PROCESSING' THEN 'UNDER_REVIEW' ELSE status END;
ALTER TABLE crypto_deposits ADD CONSTRAINT crypto_deposits_funding_status CHECK (status IN ('PENDING','UNDER_REVIEW','APPROVED','REJECTED','COMPLETED'));

CREATE TABLE withdrawal_instruments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), customer_id uuid NOT NULL REFERENCES users(id),
  country text NOT NULL, currency text NOT NULL CHECK (currency IN ('USD','EUR','GBP')),
  account_holder_name text NOT NULL, bank_name text NOT NULL, account_number_encrypted text,
  routing_number_encrypted text, iban_encrypted text, swift_bic_encrypted text,
  local_bank_identifier_encrypted text, bank_address text, account_last_four text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX withdrawal_instruments_customer_idx ON withdrawal_instruments(customer_id, created_at DESC);

CREATE TABLE bank_withdrawals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), withdrawal_id text NOT NULL UNIQUE,
  activity_id text NOT NULL UNIQUE, customer_id uuid NOT NULL REFERENCES users(id),
  source_account_id uuid NOT NULL REFERENCES accounts(id), instrument_id uuid NOT NULL REFERENCES withdrawal_instruments(id),
  currency text NOT NULL CHECK (currency IN ('USD','EUR','GBP')), amount numeric(24,8) NOT NULL CHECK(amount>0),
  fee numeric(24,8) NOT NULL DEFAULT 0 CHECK(fee>=0), status text NOT NULL DEFAULT 'PENDING_REVIEW'
    CHECK(status IN ('PENDING_REVIEW','APPROVED','MANUAL_PROCESSING','COMPLETED','REJECTED')),
  idempotency_key text NOT NULL UNIQUE, reservation_transaction_id uuid NOT NULL REFERENCES transactions(id),
  settlement_transaction_id uuid REFERENCES transactions(id), external_payment_reference text,
  processing_date date, reviewed_by text, admin_reason text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz
);
CREATE INDEX bank_withdrawals_customer_idx ON bank_withdrawals(customer_id, created_at DESC);
CREATE INDEX bank_withdrawals_status_idx ON bank_withdrawals(status, created_at);

CREATE OR REPLACE FUNCTION protect_financial_postings() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.customer_id<>OLD.customer_id OR NEW.source_account_id<>OLD.source_account_id OR NEW.instrument_id<>OLD.instrument_id
     OR NEW.currency<>OLD.currency OR NEW.amount<>OLD.amount OR NEW.fee<>OLD.fee
     OR NEW.reservation_transaction_id<>OLD.reservation_transaction_id
     OR (OLD.settlement_transaction_id IS NOT NULL AND NEW.settlement_transaction_id IS DISTINCT FROM OLD.settlement_transaction_id) THEN
    RAISE EXCEPTION 'Withdrawal financial fields are immutable';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER bank_withdrawals_protect_postings BEFORE UPDATE ON bank_withdrawals FOR EACH ROW EXECUTE FUNCTION protect_financial_postings();

CREATE OR REPLACE FUNCTION validate_crypto_destination() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE owner uuid; destination_currency text;
BEGIN
  IF NEW.destination_account_id IS NOT NULL THEN
    SELECT user_id,currency INTO owner,destination_currency FROM accounts WHERE id=NEW.destination_account_id;
    IF owner IS DISTINCT FROM NEW.customer_id OR destination_currency NOT IN ('USD','EUR','GBP') THEN
      RAISE EXCEPTION 'Crypto destination must be a fiat account owned by the customer';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER crypto_deposits_validate_destination BEFORE INSERT OR UPDATE OF destination_account_id ON crypto_deposits FOR EACH ROW EXECUTE FUNCTION validate_crypto_destination();
