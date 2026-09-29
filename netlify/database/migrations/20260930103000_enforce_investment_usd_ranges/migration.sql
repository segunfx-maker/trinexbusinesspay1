ALTER TABLE investment_positions
  ADD COLUMN principal_usd numeric(30,12),
  ADD COLUMN valuation_price_usd numeric(30,12),
  ADD COLUMN valuation_source text,
  ADD COLUMN valuation_timestamp timestamptz;

CREATE OR REPLACE FUNCTION enforce_investment_usd_range() RETURNS trigger AS $$
BEGIN
  IF NEW.principal_usd IS NULL OR NEW.principal_usd <= 0 THEN
    RAISE EXCEPTION 'A precise USD investment amount is required';
  END IF;
  IF (NEW.plan_id = 'GOLD' AND (NEW.principal_usd < 5000 OR NEW.principal_usd > 20000))
    OR (NEW.plan_id = 'DIAMOND' AND (NEW.principal_usd < 21000 OR NEW.principal_usd > 100000))
    OR (NEW.plan_id = 'PLATINUM' AND NEW.principal_usd < 110000)
    OR NEW.plan_id NOT IN ('GOLD','DIAMOND','PLATINUM') THEN
    RAISE EXCEPTION 'Investment amount is outside the authoritative USD plan range';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER investment_positions_enforce_usd_range
BEFORE INSERT OR UPDATE OF plan_id, principal_usd ON investment_positions
FOR EACH ROW EXECUTE FUNCTION enforce_investment_usd_range();

-- Unlimited plans use NULL for the maximum. The original plan schema required a
-- numeric sentinel, so relax that legacy restriction before correcting Platinum.
ALTER TABLE investment_plans ALTER COLUMN maximum_amount DROP NOT NULL;

UPDATE investment_plans SET minimum_amount=5000,maximum_amount=20000,maximum_unlimited=false WHERE id='GOLD';
UPDATE investment_plans SET minimum_amount=21000,maximum_amount=100000,maximum_unlimited=false WHERE id='DIAMOND';
UPDATE investment_plans SET minimum_amount=110000,maximum_amount=NULL,maximum_unlimited=true WHERE id='PLATINUM';

ALTER TABLE investment_plans ADD CONSTRAINT investment_plans_authoritative_usd_ranges CHECK (
  (id='GOLD' AND minimum_amount=5000 AND maximum_amount=20000 AND maximum_unlimited=false)
  OR (id='DIAMOND' AND minimum_amount=21000 AND maximum_amount=100000 AND maximum_unlimited=false)
  OR (id='PLATINUM' AND minimum_amount=110000 AND maximum_amount IS NULL AND maximum_unlimited=true)
);
