INSERT INTO accounts (user_id, currency, environment, status, account_owner_type)
SELECT u.id, currency, 'PRODUCTION', 'ACTIVE', 'CUSTOMER'
FROM users u CROSS JOIN (VALUES ('USD'), ('EUR'), ('GBP')) supported(currency)
ON CONFLICT DO NOTHING;

ALTER TABLE accounts ADD CONSTRAINT accounts_supported_currency CHECK (currency IN ('USD', 'EUR', 'GBP'));

ALTER TABLE ledger_entries ADD COLUMN account_id uuid;
ALTER TABLE ledger_entries ADD COLUMN status transfer_status;
UPDATE ledger_entries e SET account_id=la.account_id, status=t.status
FROM ledger_accounts la, transactions t
WHERE e.ledger_account_id=la.id AND e.transaction_id=t.id;
ALTER TABLE ledger_entries ALTER COLUMN account_id SET NOT NULL;
ALTER TABLE ledger_entries ALTER COLUMN status SET NOT NULL;
ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_account_id_accounts_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(id);

CREATE OR REPLACE FUNCTION validate_account_currency_chain() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE account_currency text; resolved_account_id uuid; resolved_status transfer_status;
BEGIN
  SELECT a.currency, a.id, t.status INTO account_currency, resolved_account_id, resolved_status
  FROM ledger_accounts la JOIN accounts a ON a.id=la.account_id
  JOIN transactions t ON t.id=NEW.transaction_id
  WHERE la.id=NEW.ledger_account_id;
  IF account_currency IS NULL OR NEW.currency<>account_currency THEN RAISE EXCEPTION 'Ledger entry currency must match its customer account'; END IF;
  NEW.account_id := resolved_account_id;
  NEW.status := resolved_status;
  RETURN NEW;
END $$;
CREATE TRIGGER ledger_entries_validate_account_currency BEFORE INSERT ON ledger_entries FOR EACH ROW EXECUTE FUNCTION validate_account_currency_chain();
