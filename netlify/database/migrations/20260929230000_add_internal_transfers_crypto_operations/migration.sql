ALTER TABLE accounts DROP CONSTRAINT accounts_supported_currency;
ALTER TABLE accounts ADD CONSTRAINT accounts_supported_currency CHECK (currency IN ('USD','EUR','GBP','BTC','ETH'));

ALTER TABLE transfers ADD COLUMN transfer_reference text;
ALTER TABLE transfers ADD COLUMN sender_customer_id uuid REFERENCES users(id);
ALTER TABLE transfers ADD COLUMN recipient_customer_id uuid REFERENCES users(id);
ALTER TABLE transfers ADD COLUMN idempotency_key text;
CREATE UNIQUE INDEX transfers_idempotency_key_unique ON transfers(idempotency_key) WHERE idempotency_key IS NOT NULL;

CREATE TYPE crypto_operation_status AS ENUM ('PENDING_REVIEW','APPROVED','MANUALLY_PROCESSING','REJECTED','COMPLETED');

CREATE TABLE crypto_deposits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deposit_id text NOT NULL UNIQUE,
  customer_id uuid NOT NULL REFERENCES users(id),
  asset text NOT NULL CHECK (asset IN ('BTC','ETH')),
  network text NOT NULL,
  receiving_address text NOT NULL,
  amount numeric(30,12) NOT NULL CHECK (amount > 0),
  transaction_hash text,
  status crypto_operation_status NOT NULL DEFAULT 'PENDING_REVIEW',
  idempotency_key text NOT NULL UNIQUE,
  ledger_transaction_id uuid REFERENCES transactions(id),
  reviewing_admin_identity_id text,
  review_note text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX crypto_deposits_customer_created_idx ON crypto_deposits(customer_id, created_at DESC);
CREATE INDEX crypto_deposits_status_idx ON crypto_deposits(status, created_at);

ALTER TABLE crypto_withdrawals ALTER COLUMN status DROP DEFAULT;
ALTER TABLE crypto_withdrawals ALTER COLUMN status TYPE text USING status::text;
UPDATE crypto_withdrawals SET status=CASE status
  WHEN 'WITHDRAWAL_REQUESTED' THEN 'PENDING_REVIEW'
  WHEN 'UNDER_REVIEW' THEN 'PENDING_REVIEW'
  WHEN 'PROCESSING' THEN 'MANUALLY_PROCESSING'
  ELSE status END;
ALTER TABLE crypto_withdrawals ADD CONSTRAINT crypto_withdrawals_manual_status_check
  CHECK (status IN ('PENDING_REVIEW','APPROVED','MANUALLY_PROCESSING','COMPLETED','REJECTED','BROADCAST','CONFIRMED','FAILED','CANCELED'));
ALTER TABLE crypto_withdrawals ALTER COLUMN status SET DEFAULT 'PENDING_REVIEW';
ALTER TABLE crypto_withdrawals ADD COLUMN network text NOT NULL DEFAULT 'Bitcoin';
ALTER TABLE crypto_withdrawals ADD COLUMN customer_note text;
ALTER TABLE crypto_withdrawals ADD COLUMN ledger_transaction_id uuid REFERENCES transactions(id);
ALTER TABLE crypto_withdrawals ADD COLUMN reviewing_admin_identity_id text;
ALTER TABLE crypto_withdrawals ADD COLUMN admin_note text;
ALTER TABLE crypto_withdrawals ADD COLUMN rejection_reason text;
ALTER TABLE crypto_withdrawals ADD COLUMN reviewed_at timestamptz;

INSERT INTO crypto_assets(symbol,name,precision,enabled) VALUES ('BTC','Bitcoin',8,true),('ETH','Ethereum',8,true)
ON CONFLICT (symbol) DO UPDATE SET enabled=true;

CREATE OR REPLACE FUNCTION prevent_crypto_posting_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.ledger_transaction_id IS NOT NULL AND NEW.ledger_transaction_id IS DISTINCT FROM OLD.ledger_transaction_id THEN
    RAISE EXCEPTION 'Posted crypto ledger association is immutable';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER crypto_deposits_protect_posting BEFORE UPDATE ON crypto_deposits FOR EACH ROW EXECUTE FUNCTION prevent_crypto_posting_mutation();
CREATE TRIGGER crypto_withdrawals_protect_posting BEFORE UPDATE ON crypto_withdrawals FOR EACH ROW EXECUTE FUNCTION prevent_crypto_posting_mutation();
