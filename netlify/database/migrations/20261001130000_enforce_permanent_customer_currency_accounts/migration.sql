-- Consolidate legacy duplicate customer currency accounts without losing financial history,
-- then enforce one permanent USD, EUR and GBP account per customer.
CREATE TABLE customer_account_migration_archive (
  account_id uuid PRIMARY KEY,
  canonical_account_id uuid NOT NULL REFERENCES accounts(id),
  customer_id uuid NOT NULL REFERENCES users(id),
  currency text NOT NULL,
  internal_account_number text NOT NULL,
  status text NOT NULL,
  environment environment NOT NULL,
  created_at timestamptz NOT NULL,
  closed_at timestamptz,
  archived_at timestamptz NOT NULL DEFAULT now(),
  reason text NOT NULL DEFAULT 'DUPLICATE_CURRENCY_ACCOUNT_CONSOLIDATION'
);

CREATE TEMP TABLE duplicate_customer_account_map ON COMMIT DROP AS
WITH ranked AS (
  SELECT id, user_id, currency,
    first_value(id) OVER (PARTITION BY user_id,currency ORDER BY CASE status WHEN 'ACTIVE' THEN 0 WHEN 'RESTRICTED' THEN 1 ELSE 2 END,created_at,id) canonical_id,
    row_number() OVER (PARTITION BY user_id,currency ORDER BY CASE status WHEN 'ACTIVE' THEN 0 WHEN 'RESTRICTED' THEN 1 ELSE 2 END,created_at,id) position
  FROM accounts WHERE account_owner_type='CUSTOMER' AND currency IN ('USD','EUR','GBP')
)
SELECT id duplicate_id,canonical_id,user_id,currency FROM ranked WHERE position>1;

INSERT INTO customer_account_migration_archive(account_id,canonical_account_id,customer_id,currency,internal_account_number,status,environment,created_at,closed_at)
SELECT a.id,m.canonical_id,a.user_id,a.currency,a.internal_account_number,a.status,a.environment,a.created_at,a.closed_at
FROM duplicate_customer_account_map m JOIN accounts a ON a.id=m.duplicate_id;

ALTER TABLE ledger_entries DISABLE TRIGGER USER;
ALTER TABLE ledger_accounts DISABLE TRIGGER USER;
ALTER TABLE transfers DISABLE TRIGGER USER;
ALTER TABLE crypto_deposits DISABLE TRIGGER USER;
ALTER TABLE bank_withdrawals DISABLE TRIGGER USER;
ALTER TABLE investment_positions DISABLE TRIGGER USER;
UPDATE ledger_entries e SET account_id=m.canonical_id FROM duplicate_customer_account_map m WHERE e.account_id=m.duplicate_id;
UPDATE ledger_accounts a SET account_id=m.canonical_id FROM duplicate_customer_account_map m WHERE a.account_id=m.duplicate_id;
UPDATE transfers t SET sender_account_id=m.canonical_id FROM duplicate_customer_account_map m WHERE t.sender_account_id=m.duplicate_id;
UPDATE transfers t SET recipient_account_id=m.canonical_id FROM duplicate_customer_account_map m WHERE t.recipient_account_id=m.duplicate_id;
UPDATE crypto_deposits d SET destination_account_id=m.canonical_id FROM duplicate_customer_account_map m WHERE d.destination_account_id=m.duplicate_id;
UPDATE bank_withdrawals w SET source_account_id=m.canonical_id FROM duplicate_customer_account_map m WHERE w.source_account_id=m.duplicate_id;
UPDATE investment_positions p SET funding_account_id=m.canonical_id FROM duplicate_customer_account_map m WHERE p.funding_account_id=m.duplicate_id;
ALTER TABLE investment_positions ENABLE TRIGGER USER;
ALTER TABLE bank_withdrawals ENABLE TRIGGER USER;
ALTER TABLE crypto_deposits ENABLE TRIGGER USER;
ALTER TABLE transfers ENABLE TRIGGER USER;
ALTER TABLE ledger_accounts ENABLE TRIGGER USER;
ALTER TABLE ledger_entries ENABLE TRIGGER USER;

INSERT INTO audit_events(activity_id,actor_identity_id,action,entity_type,entity_id,metadata)
SELECT gen_random_uuid()::text,u.identity_id,'DUPLICATE_CURRENCY_ACCOUNT_CONSOLIDATED','account',m.duplicate_id::text,
 json_build_object('duplicateAccountId',m.duplicate_id,'canonicalAccountId',m.canonical_id,'customerId',m.user_id,'currency',m.currency,'strategy','prefer active then oldest')::text
FROM duplicate_customer_account_map m JOIN users u ON u.id=m.user_id;
DELETE FROM accounts a USING duplicate_customer_account_map m WHERE a.id=m.duplicate_id;

CREATE UNIQUE INDEX accounts_customer_currency_unique ON accounts(user_id,currency) WHERE account_owner_type='CUSTOMER';
