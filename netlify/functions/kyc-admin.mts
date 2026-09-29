import type { Config, Context } from "@netlify/functions"
import { DOCUMENT_TYPES, errorResponse, json, KYC_STATUSES, requireComplianceAdmin } from "./_shared/kyc.mts"

export default async (req: Request, context: Context) => {
  try {
    const { admin, db } = await requireComplianceAdmin()
    if (req.method !== "GET") return new Response("Method not allowed", { status: 405 })
    const caseId = context.params.id
    if (caseId) {
      const result = await db.pool.query(
        `SELECT k.*,u.full_name AS customer_name,u.email AS customer_email,u.trinex_id,
          COALESCE(json_agg(json_build_object('id',d.id,'kind',d.document_kind,'contentType',d.content_type,'size',d.byte_size,'uploadedAt',d.created_at))
            FILTER (WHERE d.id IS NOT NULL),'[]') AS documents
         FROM kyc_submissions k JOIN users u ON u.id=k.customer_id LEFT JOIN kyc_documents d ON d.kyc_case_id=k.id
         WHERE k.id=$1 GROUP BY k.id,u.id`, [caseId],
      )
      if (!result.rows[0]) return json({ error: "KYC case not found." }, 404)
      const item = result.rows[0]
      delete item.document_number_ciphertext
      delete item.identification_number
      return json({ case: item, reviewerRole: admin.role })
    }
    const url = new URL(req.url)
    const status = url.searchParams.get("status")
    const documentType = url.searchParams.get("documentType")
    const country = url.searchParams.get("country")
    const from = url.searchParams.get("from")
    const to = url.searchParams.get("to")
    const search = url.searchParams.get("search")?.trim()
    if (status && !KYC_STATUSES.includes(status as (typeof KYC_STATUSES)[number])) return json({ error: "Invalid status filter." }, 422)
    if (documentType && !DOCUMENT_TYPES.includes(documentType as (typeof DOCUMENT_TYPES)[number])) return json({ error: "Invalid document filter." }, 422)
    const values: unknown[] = []
    const where: string[] = []
    const add = (clause: string, value: unknown) => { values.push(value); where.push(clause.replace("?", `$${values.length}`)) }
    if (status) add("k.status=?", status)
    if (documentType) add("k.identification_type=?", documentType)
    if (country) add("k.issuing_country=?", country)
    if (from) add("k.submitted_at>=?::date", from)
    if (to) add("k.submitted_at<?::date + interval '1 day'", to)
    if (search) { values.push(`%${search.slice(0,120)}%`); where.push(`(u.full_name ILIKE $${values.length} OR u.email ILIKE $${values.length} OR u.trinex_id ILIKE $${values.length} OR u.id::text ILIKE $${values.length})`) }
    const result = await db.pool.query(
      `SELECT k.id,u.full_name AS customer_name,u.email AS customer_email,u.id AS customer_id,u.trinex_id,
              k.status,k.submitted_at,k.identification_type,k.issuing_country,k.expiration_date,k.review_started_at,k.reviewed_at
         FROM kyc_submissions k JOIN users u ON u.id=k.customer_id
         ${where.length ? `WHERE ${where.join(" AND ")}` : ""}
        ORDER BY CASE k.status WHEN 'SUBMITTED' THEN 0 WHEN 'UNDER_REVIEW' THEN 1 ELSE 2 END,k.submitted_at DESC NULLS LAST LIMIT 200`, values,
    )
    const statsResult = await db.pool.query(`SELECT status,count(*)::int AS count FROM kyc_submissions GROUP BY status`)
    const stats = Object.fromEntries(KYC_STATUSES.map(s => [s, 0]))
    for (const row of statsResult.rows) stats[row.status] = row.count
    return json({ cases: result.rows, stats })
  } catch (error) { return errorResponse(error) }
}

export const config: Config = { path: ["/api/admin/kyc", "/api/admin/kyc/:id"] }
