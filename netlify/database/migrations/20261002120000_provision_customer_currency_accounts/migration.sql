-- Provision the three permanent fiat accounts when a customer record is created.
-- Account reads, including the Overview, remain read-only.
CREATE OR REPLACE FUNCTION provision_customer_currency_accounts() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO accounts (user_id, currency, environment, status, account_owner_type)
  SELECT NEW.id, currency, 'PRODUCTION', 'ACTIVE', 'CUSTOMER'
  FROM (VALUES ('USD'), ('EUR'), ('GBP')) supported(currency)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END $$;

CREATE TRIGGER users_provision_customer_currency_accounts
AFTER INSERT ON users
FOR EACH ROW EXECUTE FUNCTION provision_customer_currency_accounts();
