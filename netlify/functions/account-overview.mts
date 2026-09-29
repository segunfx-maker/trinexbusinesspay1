import type { Config } from "@netlify/functions"
import { errorResponse, json, requireCustomer } from "./_shared/kyc.mts"

export default async (req: Request) => {
  try {
    if (req.method !== "GET") return new Response("Method not allowed", { status: 405 })
    const { customer, db } = await requireCustomer()
    const [accounts, transactions, crypto, kyc] = await Promise.all([
      db.pool.query(`SELECT a.id,a.currency,a.status,a.internal_account_number,
        COALESCE(SUM(CASE e.direction WHEN 'CREDIT' THEN e.amount ELSE -e.amount END),0)::text balance
        FROM accounts a LEFT JOIN ledger_entries e ON e.account_id=a.id AND e.status='COMPLETED'
        WHERE a.user_id=$1 AND a.account_owner_type='CUSTOMER' AND a.environment='PRODUCTION'
        GROUP BY a.id ORDER BY array_position(ARRAY['USD','EUR','GBP','BTC','ETH'],a.currency)`, [customer.id]),
      db.pool.query(`SELECT t.id,t.type,t.amount::text,t.currency,t.status,t.created_at,t.event_type
        FROM transactions t JOIN ledger_entries e ON e.transaction_id=t.id JOIN accounts a ON a.id=e.account_id
        WHERE a.user_id=$1 GROUP BY t.id ORDER BY t.created_at DESC LIMIT 25`, [customer.id]),
      db.pool.query(`SELECT ca.symbol,ca.name,cb.available::text,cb.reserved::text,
        (SELECT cps.price::text FROM crypto_price_snapshots cps WHERE cps.asset_id=ca.id ORDER BY cps.created_at DESC LIMIT 1) price_usd
        FROM crypto_balances cb JOIN crypto_assets ca ON ca.id=cb.asset_id WHERE cb.user_id=$1 ORDER BY ca.symbol`, [customer.id]),
      db.pool.query(`SELECT status,expiration_date FROM kyc_submissions WHERE customer_id=$1 LIMIT 1`, [customer.id]),
    ])
    return json({ customer, accounts: accounts.rows, transactions: transactions.rows, crypto: crypto.rows, kyc: kyc.rows[0] ?? { status: "NOT_STARTED" } })
  } catch (error) { return errorResponse(error) }
}

export const config: Config = { path: "/api/account-overview" }
