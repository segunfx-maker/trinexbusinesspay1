import { getDatabase } from "@netlify/database"
import { getUser } from "@netlify/identity"

export const KYC_STATUSES = ["NOT_STARTED", "DRAFT", "SUBMITTED", "UNDER_REVIEW", "APPROVED", "REJECTED", "EXPIRED"] as const
export const DOCUMENT_TYPES = ["PASSPORT", "NATIONAL_ID", "DRIVERS_LICENSE", "GOVERNMENT_ID"] as const
export const COMPLIANCE_ROLES = ["SUPER_ADMIN", "ADMIN", "COMPLIANCE"] as const
export const KYC_REQUIRED_MESSAGE = "KYC verification is required before you can use this feature."

export type KycStatus = (typeof KYC_STATUSES)[number]

export function canEditKyc(status: string, resubmissionPermitted = true) {
  return ["NOT_STARTED", "DRAFT", "EXPIRED"].includes(status) || (status === "REJECTED" && resubmissionPermitted)
}

export function effectiveKycStatus(status: string, expirationDate?: string | Date | null, now = new Date()): KycStatus {
  if (status === "APPROVED" && expirationDate && new Date(expirationDate).getTime() < now.getTime()) return "EXPIRED"
  return KYC_STATUSES.includes(status as KycStatus) ? status as KycStatus : "NOT_STARTED"
}

export function canAccessKycDocument(actorCustomerId: string | undefined, actorRole: string | undefined, ownerCustomerId: string) {
  return actorCustomerId === ownerCustomerId || COMPLIANCE_ROLES.includes(actorRole as (typeof COMPLIANCE_ROLES)[number])
}

export function buildKycAuditRecord(input: { adminId: string; customerId: string; caseId: string; previousStatus: string; newStatus: string; reason: string }) {
  if (!input.reason.trim()) throw new Error("An admin reason is required.")
  return { ...input, reason: input.reason.trim() }
}

export function json(data: unknown, status = 200) {
  return Response.json(data, { status, headers: { "Cache-Control": "no-store" } })
}

export function cleanText(value: unknown, max = 240): string | null {
  if (typeof value !== "string") return null
  const normalized = value.trim().replace(/\s+/g, " ")
  return normalized ? normalized.slice(0, max) : null
}

export async function requireIdentity() {
  const identity = await getUser()
  if (!identity) throw Object.assign(new Error("Authentication required."), { status: 401 })
  return identity as typeof identity & { id: string; email?: string; appMetadata?: { roles?: string[] } }
}

export async function requireCustomer() {
  const identity = await requireIdentity()
  const db = getDatabase()
  const result = await db.pool.query(
    `SELECT u.id, u.email, u.full_name, u.trinex_id
       FROM users u
      WHERE u.identity_id=$1
         OR EXISTS (SELECT 1 FROM customer_auth_identities cai WHERE cai.customer_id=u.id AND cai.provider_subject=$1)
      LIMIT 1`,
    [identity.id],
  )
  if (!result.rows[0]) throw Object.assign(new Error("Customer account not found."), { status: 403 })
  return { identity, customer: result.rows[0] as { id: string; email: string; full_name: string; trinex_id: string }, db }
}

export async function requireComplianceAdmin() {
  const identity = await requireIdentity()
  const db = getDatabase()
  const result = await db.pool.query(
    `SELECT identity_id, email, role FROM admin_identities WHERE identity_id=$1 AND active=true LIMIT 1`,
    [identity.id],
  )
  const admin = result.rows[0] as { identity_id: string; email: string; role: string } | undefined
  if (!admin || !COMPLIANCE_ROLES.includes(admin.role as (typeof COMPLIANCE_ROLES)[number])) {
    throw Object.assign(new Error("Compliance authorization required."), { status: 403 })
  }
  return { identity, admin, db }
}

function encryptionKey() {
  const raw = Netlify.env.get("KYC_DATA_ENCRYPTION_KEY") ?? Netlify.env.get("ADMIN_MFA_ENCRYPTION_KEY")
  if (!raw) throw Object.assign(new Error("KYC encryption is not configured."), { status: 503 })
  return crypto.subtle.digest("SHA-256", new TextEncoder().encode(`trinex-kyc-v1:${raw}`))
}

export async function encryptSensitive(value: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12))
  const key = await crypto.subtle.importKey("raw", await encryptionKey(), "AES-GCM", false, ["encrypt"])
  const encrypted = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(value))
  return `${Buffer.from(iv).toString("base64url")}.${Buffer.from(encrypted).toString("base64url")}`
}

export async function assertApprovedKyc(client: { query: (text: string, values?: unknown[]) => Promise<{ rows: unknown[] }> }, customerId: string) {
  const result = await client.query(
    `SELECT 1 FROM users u JOIN kyc_submissions k ON k.customer_id=u.id
      WHERE u.id=$1 AND k.status='APPROVED' AND (k.expiration_date IS NULL OR k.expiration_date >= CURRENT_DATE)`,
    [customerId],
  )
  if (!result.rows[0]) throw Object.assign(new Error(KYC_REQUIRED_MESSAGE), { status: 403, code: "KYC_REQUIRED" })
}

export function errorResponse(error: unknown) {
  const status = typeof error === "object" && error && "status" in error ? Number(error.status) : 500
  const safeStatus = Number.isInteger(status) && status >= 400 && status < 600 ? status : 500
  const message = error instanceof Error && safeStatus < 500 ? error.message : "Unable to complete the request."
  return json({ error: message }, safeStatus)
}
