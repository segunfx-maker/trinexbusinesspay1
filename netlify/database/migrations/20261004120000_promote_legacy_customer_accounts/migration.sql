-- Permanent customer fiat accounts predate production account provisioning and
-- may retain the original SANDBOX default. Promote those same accounts in
-- place so financial workflows and customer reads address one ledger source.
UPDATE accounts
SET environment = 'PRODUCTION'
WHERE account_owner_type = 'CUSTOMER'
  AND currency IN ('USD', 'EUR', 'GBP')
  AND environment = 'SANDBOX';

ALTER TABLE accounts ADD CONSTRAINT customer_fiat_accounts_are_production CHECK (
  account_owner_type <> 'CUSTOMER'
  OR currency NOT IN ('USD', 'EUR', 'GBP')
  OR environment = 'PRODUCTION'
);
