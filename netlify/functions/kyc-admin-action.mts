import type { Config, Context } from "@netlify/functions"
import { buildKycAuditRecord, cleanText, errorResponse, json, requireComplianceAdmin } from "./_shared/kyc.mts"

const transitions: Record<string, string[]> = {
  UNDER_REVIEW: ["SUBMITTED"],
  APPROVED: ["SUBMITTED", "UNDER_REVIEW"],
  REJECTED: ["SUBMITTED", "UNDER_REVIEW"],
  EXPIRED: ["APPROVED", "SUBMITTED", "UNDER_REVIEW"],
}

export default async (req: Request, context: Context) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 })
    const { admin, db } = await requireComplianceAdmin()
    const caseId = context.params.id
    const body = await req.json() as Record<string, unknown>
    const action = cleanText(body.action, 40)
    const reason = cleanText(body.reason, 1000)
    const corrections = cleanText(body.corrections, 2000)
    const newStatus = action === "REQUEST_INFORMATION" ? "REJECTED" : action
    if (!caseId || !newStatus || !transitions[newStatus] || !reason) return json({ error: "A valid action and admin reason are required." }, 422)
    const client = await db.pool.connect()
    try {
      await client.query("BEGIN")
      const result = await client.query(`SELECT * FROM kyc_submissions WHERE id=$1 FOR UPDATE`, [caseId])
      const current = result.rows[0]
      if (!current) { await client.query("ROLLBACK"); return json({ error: "KYC case not found." }, 404) }
      if (!transitions[newStatus].includes(current.status)) { await client.query("ROLLBACK"); return json({ error: `Cannot move this case from ${current.status} to ${newStatus}.` }, 409) }
      if (newStatus === "APPROVED") {
        if (!current.attested || !current.document_number_ciphertext || (current.expiration_date && new Date(current.expiration_date) < new Date())) {
          await client.query("ROLLBACK"); return json({ error: "An incomplete or expired case cannot be approved." }, 422)
        }
      }
      await client.query(
        `UPDATE kyc_submissions SET status=$1,decision_reason=$2,correction_details=$3,resubmission_permitted=$4,
          review_started_at=CASE WHEN $1='UNDER_REVIEW' THEN COALESCE(review_started_at,now()) ELSE review_started_at END,
          reviewed_at=CASE WHEN $1 IN ('APPROVED','REJECTED','EXPIRED') THEN now() ELSE reviewed_at END,
          reviewer_admin_id=$5,updated_at=now() WHERE id=$6`,
        [newStatus, reason, action === "REQUEST_INFORMATION" ? (corrections ?? reason) : corrections, newStatus !== "APPROVED", admin.identity_id, caseId],
      )
      const audit = buildKycAuditRecord({ adminId: admin.identity_id, customerId: current.customer_id, caseId, previousStatus: current.status, newStatus, reason })
      await client.query(
        `INSERT INTO kyc_audit_log(admin_identity_id,customer_id,kyc_case_id,previous_status,new_status,reason)
         VALUES($1,$2,$3,$4,$5,$6)`, [audit.adminId,audit.customerId,audit.caseId,audit.previousStatus,audit.newStatus,audit.reason],
      )
      await client.query("COMMIT")
      return json({ updated: true, previousStatus: current.status, status: newStatus })
    } catch (error) { await client.query("ROLLBACK"); throw error } finally { client.release() }
  } catch (error) { return errorResponse(error) }
}

export const config: Config = { path: "/api/admin/kyc/:id/action" }
