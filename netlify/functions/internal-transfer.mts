import type { Config } from "@netlify/functions"
import { accountNumber, customer, idempotency, money, response } from "./_shared/finance.mts"

export default async (req: Request) => {
  try {
    const { customer: sender, db } = await customer(); const body = req.method === "GET" ? {} : await req.json() as Record<string, unknown>
    if (req.method === "GET") {
      const number = accountNumber(new URL(req.url).searchParams.get("accountNumber"))
      const found = await db.pool.query(`SELECT a.currency,u.full_name FROM accounts a JOIN users u ON u.id=a.user_id WHERE a.internal_account_number=$1 AND a.account_owner_type='CUSTOMER' AND a.status='ACTIVE' LIMIT 1`, [number])
      if (!found.rows[0]) return Response.json({ error: "Recipient account not found." }, { status: 404 })
      return Response.json({ recipientName: found.rows[0].full_name, currency: found.rows[0].currency })
    }
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 })
    const number = accountNumber(body.accountNumber), amount = money(body.amount), currency = String(body.currency ?? "").toUpperCase(), key = idempotency(req, body)
    const note = typeof body.note === "string" ? body.note.trim().slice(0, 240) : null; const client = await db.pool.connect()
    try {
      await client.query("BEGIN")
      const prior = await client.query(`SELECT transfer_reference,status FROM transfers WHERE idempotency_key=$1`, [key]); if (prior.rows[0]) { await client.query("COMMIT"); return Response.json(prior.rows[0]) }
      const accounts = await client.query(`SELECT a.id,a.user_id,a.currency,a.status,a.internal_account_number,u.full_name,la.id ledger_id,
        COALESCE((SELECT sum(CASE WHEN e.direction='CREDIT' THEN e.amount ELSE -e.amount END) FROM ledger_entries e WHERE e.account_id=a.id AND e.status='COMPLETED'),0) balance
        FROM accounts a JOIN users u ON u.id=a.user_id JOIN ledger_accounts la ON la.account_id=a.id
        WHERE (a.user_id=$1 AND a.currency=$2 OR a.internal_account_number=$3) AND a.account_owner_type='CUSTOMER' FOR UPDATE OF a`, [sender.id,currency,number])
      const source=accounts.rows.find((x:any)=>x.user_id===sender.id), recipient=accounts.rows.find((x:any)=>x.internal_account_number===number)
      if (!source || source.status!=="ACTIVE") throw Object.assign(new Error("Active sender account not found."),{status:400})
      if (!recipient || recipient.status!=="ACTIVE") throw Object.assign(new Error("Active recipient account not found."),{status:404})
      if (source.id===recipient.id) throw Object.assign(new Error("You cannot transfer to the same account."),{status:400})
      if (source.currency!==recipient.currency || source.currency!==currency) throw Object.assign(new Error("Transfers require matching currencies."),{status:400})
      if (Number(source.balance)<Number(amount)) throw Object.assign(new Error("Insufficient available balance."),{status:409})
      const activity=`ACT-${crypto.randomUUID()}`, reference=`TRF-${crypto.randomUUID()}`
      const tx=await client.query(`INSERT INTO transactions(transaction_id,activity_id,idempotency_key,currency,amount,status,environment,event_type) VALUES($1,$2,$3,$4,$5,'COMPLETED','PRODUCTION','INTERNAL_TRANSFER') RETURNING id`,[reference,activity,`tx:${key}`,currency,amount])
      await client.query(`INSERT INTO audit_events(activity_id,actor_identity_id,action,entity_type,entity_id,metadata) VALUES($1,$2,'INTERNAL_TRANSFER','transfer',$3,$4)`,[activity,sender.id,reference,JSON.stringify({currency,amount})])
      await client.query(`INSERT INTO ledger_entries(transaction_id,ledger_account_id,direction,amount,currency) VALUES($1,$2,'DEBIT',$4,$3),($1,$5,'CREDIT',$4,$3)`,[tx.rows[0].id,source.ledger_id,currency,amount,recipient.ledger_id])
      await client.query(`INSERT INTO transfers(transaction_id,sender_account_id,recipient_account_id,type,status,amount,currency,note,transfer_reference,sender_customer_id,recipient_customer_id,idempotency_key) VALUES($1,$2,$3,'INTERNAL','COMPLETED',$4,$5,$6,$7,$8,$9,$10)`,[tx.rows[0].id,source.id,recipient.id,amount,currency,note,reference,sender.id,recipient.user_id,key])
      await client.query("COMMIT"); return Response.json({ transferReference:reference,status:"COMPLETED",recipientName:recipient.full_name },{status:201})
    } catch(e){await client.query("ROLLBACK");throw e} finally{client.release()}
  } catch(e){return response(e)}
}
export const config: Config={path:"/api/transfers/internal"}
