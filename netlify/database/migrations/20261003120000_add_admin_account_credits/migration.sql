-- Permanent, idempotent administrative account credits. These are internal
-- ledger events and do not represent an external bank receipt.
CREATE TABLE admin_account_credits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL UNIQUE REFERENCES transactions(id),
  account_id uuid NOT NULL REFERENCES accounts(id),
  amount numeric(24,8) NOT NULL CHECK (amount > 0),
  currency text NOT NULL CHECK (currency = 'USD'),
  admin_identity_id text NOT NULL REFERENCES admin_identities(identity_id),
  reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 8 AND 500),
  audit_event_id uuid NOT NULL UNIQUE REFERENCES audit_events(id),
  idempotency_key text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX admin_account_credits_account_created_idx
  ON admin_account_credits(account_id, created_at DESC);
CREATE INDEX admin_account_credits_admin_created_idx
  ON admin_account_credits(admin_identity_id, created_at DESC);

CREATE OR REPLACE FUNCTION prevent_admin_account_credit_mutation() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Administrative account credits are permanent; post an audited correcting transaction instead';
END $$;

CREATE TRIGGER admin_account_credits_no_update_or_delete
BEFORE UPDATE OR DELETE ON admin_account_credits
FOR EACH ROW EXECUTE FUNCTION prevent_admin_account_credit_mutation();

CREATE OR REPLACE FUNCTION protect_admin_credit_transaction() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM admin_account_credits WHERE transaction_id=OLD.id) THEN
    RAISE EXCEPTION 'Administrative credit transactions are permanent; post an audited correcting transaction instead';
  END IF;
  RETURN OLD;
END $$;

CREATE TRIGGER transactions_protect_admin_credits
BEFORE UPDATE OR DELETE ON transactions
FOR EACH ROW EXECUTE FUNCTION protect_admin_credit_transaction();
