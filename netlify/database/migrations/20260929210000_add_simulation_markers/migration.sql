ALTER TABLE transactions ADD COLUMN simulation boolean NOT NULL DEFAULT true;
ALTER TABLE accounts ADD COLUMN simulation boolean NOT NULL DEFAULT true;
ALTER TABLE financial_requests ADD COLUMN simulation boolean NOT NULL DEFAULT true;
ALTER TABLE investment_requests ADD COLUMN simulation boolean NOT NULL DEFAULT true;
ALTER TABLE crypto_requests ADD COLUMN simulation boolean NOT NULL DEFAULT true;
ALTER TABLE card_requests ADD COLUMN simulation boolean NOT NULL DEFAULT true;
ALTER TABLE kyc_submissions ADD COLUMN simulation boolean NOT NULL DEFAULT true;

ALTER TABLE transactions ADD CONSTRAINT transactions_are_simulated CHECK (simulation = true);
ALTER TABLE accounts ADD CONSTRAINT accounts_are_simulated CHECK (simulation = true);
ALTER TABLE financial_requests ADD CONSTRAINT financial_requests_are_simulated CHECK (simulation = true);
ALTER TABLE investment_requests ADD CONSTRAINT investment_requests_are_simulated CHECK (simulation = true);
ALTER TABLE crypto_requests ADD CONSTRAINT crypto_requests_are_simulated CHECK (simulation = true);
ALTER TABLE card_requests ADD CONSTRAINT card_requests_are_simulated CHECK (simulation = true);
ALTER TABLE kyc_submissions ADD CONSTRAINT kyc_submissions_are_simulated CHECK (simulation = true);
