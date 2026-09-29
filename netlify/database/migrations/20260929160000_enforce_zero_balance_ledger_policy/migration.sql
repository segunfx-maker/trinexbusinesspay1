ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_positive_amount" CHECK ("amount" > 0);
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_nonnegative_amount" CHECK ("amount" >= 0);
ALTER TABLE "crypto_balances" ADD CONSTRAINT "crypto_balances_nonnegative" CHECK ("available" >= 0 AND "reserved" >= 0);
ALTER TABLE "transactions" ADD COLUMN "event_type" text DEFAULT 'OTHER' NOT NULL;

CREATE OR REPLACE FUNCTION prevent_ledger_entry_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Ledger entries are immutable; post an audited correcting transaction instead'; END $$;
CREATE TRIGGER ledger_entries_no_update_or_delete BEFORE UPDATE OR DELETE ON "ledger_entries" FOR EACH ROW EXECUTE FUNCTION prevent_ledger_entry_mutation();

CREATE OR REPLACE FUNCTION protect_transaction_identity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.transaction_id<>OLD.transaction_id OR NEW.activity_id<>OLD.activity_id OR NEW.idempotency_key<>OLD.idempotency_key OR NEW.created_at<>OLD.created_at THEN RAISE EXCEPTION 'Transaction identity and timestamps are immutable'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER transactions_protect_identity BEFORE UPDATE ON "transactions" FOR EACH ROW EXECUTE FUNCTION protect_transaction_identity();

CREATE OR REPLACE FUNCTION validate_balanced_transaction() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE target uuid; debit_total numeric; credit_total numeric; currency_count integer;
BEGIN
  target := NEW.transaction_id;
  SELECT coalesce(sum(amount) FILTER (WHERE direction='DEBIT'),0), coalesce(sum(amount) FILTER (WHERE direction='CREDIT'),0), count(DISTINCT currency) INTO debit_total,credit_total,currency_count FROM ledger_entries WHERE transaction_id=target;
  IF debit_total<>credit_total OR currency_count<>1 THEN RAISE EXCEPTION 'Transaction % must contain balanced, single-currency double-entry postings',target; END IF;
  IF EXISTS (SELECT 1 FROM ledger_entries e JOIN transactions t ON t.id=e.transaction_id JOIN ledger_accounts a ON a.id=e.ledger_account_id WHERE e.transaction_id=target AND (e.currency<>t.currency OR e.currency<>a.currency)) THEN RAISE EXCEPTION 'Ledger entry currency must match its transaction and ledger account'; END IF;
  IF NOT EXISTS (SELECT 1 FROM transactions t JOIN audit_events a ON a.activity_id=t.activity_id WHERE t.id=target) THEN RAISE EXCEPTION 'Balance-changing transaction % requires an audit event',target; END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER ledger_transaction_must_balance AFTER INSERT ON "ledger_entries" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION validate_balanced_transaction();
