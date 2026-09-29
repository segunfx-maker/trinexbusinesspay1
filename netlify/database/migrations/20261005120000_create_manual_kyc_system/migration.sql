-- Roll forward the original minimal KYC record into a complete manual-review workflow.
ALTER TABLE kyc_submissions DROP CONSTRAINT IF EXISTS kyc_submissions_status_check;
ALTER TABLE kyc_submissions ALTER COLUMN legal_name DROP NOT NULL;
ALTER TABLE kyc_submissions ALTER COLUMN date_of_birth DROP NOT NULL;
ALTER TABLE kyc_submissions ALTER COLUMN country DROP NOT NULL;
ALTER TABLE kyc_submissions ALTER COLUMN address DROP NOT NULL;
ALTER TABLE kyc_submissions ALTER COLUMN phone DROP NOT NULL;
ALTER TABLE kyc_submissions ALTER COLUMN identification_type DROP NOT NULL;
ALTER TABLE kyc_submissions ALTER COLUMN identification_number DROP NOT NULL;
ALTER TABLE kyc_submissions ALTER COLUMN document_reference DROP NOT NULL;
ALTER TABLE kyc_submissions ALTER COLUMN status SET DEFAULT 'NOT_STARTED';

ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS legal_first_name text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS legal_middle_name text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS legal_last_name text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS nationality text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS country_of_residence text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS region text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS postal_code text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS document_number_ciphertext text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS document_number_last_four text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS issuing_country text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS issue_date date;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS expiration_date date;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS attested boolean NOT NULL DEFAULT false;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS submitted_at timestamptz;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS review_started_at timestamptz;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS reviewer_admin_id text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS decision_reason text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS correction_details text;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS resubmission_permitted boolean NOT NULL DEFAULT true;
ALTER TABLE kyc_submissions ADD COLUMN IF NOT EXISTS revision integer NOT NULL DEFAULT 1;
ALTER TABLE kyc_submissions ADD CONSTRAINT kyc_submissions_status_check
  CHECK (status IN ('NOT_STARTED','DRAFT','SUBMITTED','UNDER_REVIEW','APPROVED','REJECTED','EXPIRED'));
ALTER TABLE kyc_submissions ADD CONSTRAINT kyc_submissions_document_type_check
  CHECK (identification_type IS NULL OR identification_type IN ('PASSPORT','NATIONAL_ID','DRIVERS_LICENSE','GOVERNMENT_ID'));

CREATE TABLE kyc_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kyc_case_id uuid NOT NULL REFERENCES kyc_submissions(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  document_kind text NOT NULL CHECK (document_kind IN ('ID_FRONT','ID_BACK','SELFIE')),
  blob_key text NOT NULL UNIQUE,
  content_type text NOT NULL CHECK (content_type IN ('image/jpeg','image/png','application/pdf')),
  byte_size integer NOT NULL CHECK (byte_size > 0 AND byte_size <= 10485760),
  sha256 text NOT NULL,
  original_filename text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(kyc_case_id, document_kind)
);
CREATE INDEX kyc_documents_customer_idx ON kyc_documents(customer_id, created_at DESC);

CREATE TABLE kyc_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_identity_id text NOT NULL,
  customer_id uuid NOT NULL REFERENCES users(id),
  kyc_case_id uuid NOT NULL REFERENCES kyc_submissions(id),
  previous_status text NOT NULL,
  new_status text NOT NULL,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX kyc_audit_case_idx ON kyc_audit_log(kyc_case_id, created_at DESC);

CREATE TABLE kyc_document_access_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES kyc_documents(id),
  kyc_case_id uuid NOT NULL REFERENCES kyc_submissions(id),
  customer_id uuid NOT NULL REFERENCES users(id),
  actor_identity_id text NOT NULL,
  actor_role text NOT NULL,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX kyc_document_access_case_idx ON kyc_document_access_log(kyc_case_id, created_at DESC);

CREATE OR REPLACE FUNCTION prevent_kyc_audit_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'KYC audit records are immutable';
END $$;
CREATE TRIGGER kyc_audit_log_immutable BEFORE UPDATE OR DELETE ON kyc_audit_log FOR EACH ROW EXECUTE FUNCTION prevent_kyc_audit_mutation();
CREATE TRIGGER kyc_document_access_log_immutable BEFORE UPDATE OR DELETE ON kyc_document_access_log FOR EACH ROW EXECUTE FUNCTION prevent_kyc_audit_mutation();

INSERT INTO kyc_submissions(customer_id, status, legal_name, date_of_birth, country, address, phone, identification_type, identification_number, document_reference)
SELECT id, 'NOT_STARTED', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL FROM users
ON CONFLICT (customer_id) DO NOTHING;

CREATE OR REPLACE FUNCTION initialize_customer_kyc() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO kyc_submissions(customer_id, status) VALUES (NEW.id, 'NOT_STARTED') ON CONFLICT (customer_id) DO NOTHING;
  RETURN NEW;
END $$;
CREATE TRIGGER users_initialize_kyc AFTER INSERT ON users FOR EACH ROW EXECUTE FUNCTION initialize_customer_kyc();

CREATE OR REPLACE FUNCTION assert_customer_kyc_approved(target_customer uuid) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF target_customer IS NULL OR NOT EXISTS (
    SELECT 1 FROM users u
    JOIN kyc_submissions k ON k.customer_id=u.id
    WHERE u.id=target_customer AND k.status='APPROVED'
      AND (k.expiration_date IS NULL OR k.expiration_date >= CURRENT_DATE)
  ) THEN
    RAISE EXCEPTION 'KYC verification is required before you can use this feature.' USING ERRCODE='P0001';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION enforce_kyc_on_customer_money_movement() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM assert_customer_kyc_approved(NEW.customer_id);
  RETURN NEW;
END $$;
CREATE TRIGGER bank_withdrawals_require_kyc BEFORE INSERT ON bank_withdrawals FOR EACH ROW EXECUTE FUNCTION enforce_kyc_on_customer_money_movement();
CREATE TRIGGER crypto_deposits_require_kyc BEFORE INSERT ON crypto_deposits FOR EACH ROW EXECUTE FUNCTION enforce_kyc_on_customer_money_movement();
CREATE TRIGGER investment_positions_require_kyc BEFORE INSERT ON investment_positions FOR EACH ROW EXECUTE FUNCTION enforce_kyc_on_customer_money_movement();

CREATE OR REPLACE FUNCTION enforce_kyc_on_crypto_withdrawal() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM assert_customer_kyc_approved(NEW.user_id);
  RETURN NEW;
END $$;
CREATE TRIGGER crypto_withdrawals_require_kyc BEFORE INSERT ON crypto_withdrawals FOR EACH ROW EXECUTE FUNCTION enforce_kyc_on_crypto_withdrawal();

CREATE OR REPLACE FUNCTION enforce_kyc_on_external_transfer() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE owner_id uuid;
BEGIN
  IF NEW.type IN ('BANK','WIRE') THEN
    SELECT user_id INTO owner_id FROM accounts WHERE id=NEW.sender_account_id AND status='ACTIVE';
    IF owner_id IS NULL THEN RAISE EXCEPTION 'An active customer account is required.' USING ERRCODE='P0001'; END IF;
    PERFORM assert_customer_kyc_approved(owner_id);
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER transfers_require_kyc BEFORE INSERT ON transfers FOR EACH ROW EXECUTE FUNCTION enforce_kyc_on_external_transfer();

CREATE OR REPLACE FUNCTION enforce_kyc_on_financial_request() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF upper(NEW.request_type) ~ '(DEPOSIT|WITHDRAW|INVEST|EXTERNAL|BANK|WIRE)' THEN
    PERFORM assert_customer_kyc_approved(NEW.customer_id);
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER financial_requests_require_kyc BEFORE INSERT ON financial_requests FOR EACH ROW EXECUTE FUNCTION enforce_kyc_on_financial_request();

CREATE OR REPLACE FUNCTION expire_kyc_on_document_expiry() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status='APPROVED' AND NEW.expiration_date IS NOT NULL AND NEW.expiration_date < CURRENT_DATE THEN
    NEW.status := 'EXPIRED';
    NEW.decision_reason := 'Identification document expired; re-verification is required.';
    NEW.resubmission_permitted := true;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER kyc_expiration_guard BEFORE INSERT OR UPDATE ON kyc_submissions FOR EACH ROW EXECUTE FUNCTION expire_kyc_on_document_expiry();
