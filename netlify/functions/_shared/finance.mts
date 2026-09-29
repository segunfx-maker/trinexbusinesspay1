import { getDatabase } from "@netlify/database"
import { getUser } from "@netlify/identity"

export const ADMIN_FINANCE_ROLES = ["SUPER_ADMIN", "ADMIN", "OPERATIONS"] as const
export const FIAT = ["USD", "EUR", "GBP"] as const
export const INVESTMENT_RANGES = { GOLD: [5000, 20000], DIAMOND: [21000, 100000], PLATINUM: [110000, Infinity] } as const

export function money(value: unknown) {
  if (typeof value !== "number" && typeof value !== "string") throw Object.assign(new Error("A numeric amount is required."), { status: 400 })
  const normalized = String(value).trim()
  if (!/^\d+(\.\d{1,8})?$/.test(normalized) || Number(normalized) <= 0) throw Object.assign(new Error("Amount must be positive with at most 8 decimal places."), { status: 400 })
  return normalized
}

export function accountNumber(value: unknown) {
  const normalized = String(value ?? "").trim()
  if (!/^\d{12}$/.test(normalized)) throw Object.assign(new Error("A 12-digit account number is required."), { status: 400 })
  return normalized
}

export function idempotency(req: Request, body: Record<string, unknown>) {
  const value = req.headers.get("Idempotency-Key") ?? body.idempotencyKey
  if (typeof value !== "string" || !/^[A-Za-z0-9:_-]{12,120}$/.test(value)) throw Object.assign(new Error("A valid idempotency key is required."), { status: 400 })
  return value
}

export function investmentAmount(plan: string, value: unknown) {
  const amount = Number(money(value)); const range = INVESTMENT_RANGES[plan as keyof typeof INVESTMENT_RANGES]
  if (!range || amount < range[0] || amount > range[1]) throw Object.assign(new Error("Amount is outside the selected plan range."), { status: 400 })
  return String(value)
}

export async function identity() {
  const user = await getUser()
  if (!user) throw Object.assign(new Error("Authentication required."), { status: 401 })
  return user as typeof user & { id: string }
}

export async function customer() {
  const auth = await identity(); const db = getDatabase()
  const result = await db.pool.query(`SELECT u.id,u.full_name FROM users u WHERE u.identity_id=$1 OR EXISTS (SELECT 1 FROM customer_auth_identities c WHERE c.customer_id=u.id AND c.provider_subject=$1) LIMIT 1`, [auth.id])
  if (!result.rows[0]) throw Object.assign(new Error("Customer account not found."), { status: 403 })
  return { auth, customer: result.rows[0] as { id: string; full_name: string }, db }
}

export async function financeAdmin() {
  const auth = await identity(); const db = getDatabase()
  const result = await db.pool.query(`SELECT identity_id,role FROM admin_identities WHERE identity_id=$1 AND active=true LIMIT 1`, [auth.id])
  const admin = result.rows[0] as { identity_id: string; role: string } | undefined
  if (!admin || !ADMIN_FINANCE_ROLES.includes(admin.role as never)) throw Object.assign(new Error("Financial administration authorization required."), { status: 403 })
  return { auth, admin, db }
}

export async function approvedKyc(client: { query: Function }, customerId: string) {
  const result = await client.query(`SELECT 1 FROM kyc_submissions WHERE customer_id=$1 AND status='APPROVED' AND (expiration_date IS NULL OR expiration_date>=CURRENT_DATE)`, [customerId])
  if (!result.rows[0]) throw Object.assign(new Error("KYC verification is required before you can use this feature."), { status: 403 })
}

export function response(error: unknown) {
  const status = Number((error as { status?: number })?.status) || 500
  return Response.json({ error: status < 500 && error instanceof Error ? error.message : "Unable to complete the request." }, { status })
}
