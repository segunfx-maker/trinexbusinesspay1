import type { Config } from "@netlify/functions"
import { canEditKyc, cleanText, DOCUMENT_TYPES, encryptSensitive, errorResponse, json, requireCustomer } from "./_shared/kyc.mts"

async function getCase(db: Awaited<ReturnType<typeof requireCustomer>>["db"], customerId: string) {
  await db.pool.query(`INSERT INTO kyc_submissions(customer_id,status) VALUES($1,'NOT_STARTED') ON CONFLICT(customer_id) DO NOTHING`, [customerId])
  const result = await db.pool.query(
    `SELECT k.id, k.status, k.legal_first_name, k.legal_middle_name, k.legal_last_name, k.date_of_birth,
            k.nationality, k.country_of_residence, k.address, k.city, k.region, k.postal_code,
            k.identification_type, k.document_number_last_four, k.issuing_country, k.issue_date,
            k.expiration_date, k.phone, k.email, k.attested, k.submitted_at, k.review_started_at,
            k.reviewed_at, k.decision_reason, k.correction_details, k.resubmission_permitted,
            COALESCE(json_agg(json_build_object('id',d.id,'kind',d.document_kind,'contentType',d.content_type,'size',d.byte_size))
              FILTER (WHERE d.id IS NOT NULL),'[]') AS documents
       FROM kyc_submissions k LEFT JOIN kyc_documents d ON d.kyc_case_id=k.id
      WHERE k.customer_id=$1 GROUP BY k.id`,
    [customerId],
  )
  return result.rows[0]
}

export default async (req: Request) => {
  try {
    const { customer, db } = await requireCustomer()
    const current = await getCase(db, customer.id)
    if (req.method === "GET") return json({ kyc: current })
    if (req.method === "PUT") {
      if (!canEditKyc(current.status, current.resubmission_permitted)) {
        return json({ error: "This KYC case cannot currently be edited." }, 409)
      }
      const body = await req.json() as Record<string, unknown>
      const documentType = cleanText(body.documentType, 40)
      if (documentType && !DOCUMENT_TYPES.includes(documentType as (typeof DOCUMENT_TYPES)[number])) return json({ error: "Unsupported ID document type." }, 422)
      const documentNumber = cleanText(body.documentNumber, 120)
      const encrypted = documentNumber ? await encryptSensitive(documentNumber) : null
      const values = [
        cleanText(body.legalFirstName), cleanText(body.legalMiddleName), cleanText(body.legalLastName), cleanText(body.dateOfBirth, 10),
        cleanText(body.nationality, 80), cleanText(body.countryOfResidence, 80), cleanText(body.address, 300), cleanText(body.city, 100),
        cleanText(body.region, 100), cleanText(body.postalCode, 30), documentType, encrypted, documentNumber?.slice(-4) ?? null,
        cleanText(body.issuingCountry, 80), cleanText(body.issueDate, 10), cleanText(body.expirationDate, 10), cleanText(body.phone, 40),
        cleanText(body.email, 254) ?? customer.email, Boolean(body.attested), customer.id,
      ]
      await db.pool.query(
        `UPDATE kyc_submissions SET status='DRAFT', legal_first_name=$1, legal_middle_name=$2, legal_last_name=$3,
          date_of_birth=$4, nationality=$5, country_of_residence=$6, address=$7, city=$8, region=$9, postal_code=$10,
          identification_type=$11, document_number_ciphertext=COALESCE($12,document_number_ciphertext),
          document_number_last_four=COALESCE($13,document_number_last_four), issuing_country=$14, issue_date=$15,
          expiration_date=$16, phone=$17, email=$18, attested=$19, decision_reason=NULL, correction_details=NULL,
          reviewed_at=NULL, reviewer_admin_id=NULL, updated_at=now(), revision=CASE WHEN status IN ('REJECTED','EXPIRED') THEN revision+1 ELSE revision END
          WHERE customer_id=$20`, values,
      )
      return json({ kyc: await getCase(db, customer.id) })
    }
    if (req.method === "POST") {
      if (!canEditKyc(current.status, current.resubmission_permitted)) return json({ error: "Resubmission is not permitted." }, 409)
      const validation = await db.pool.query(
        `SELECT k.*,
          EXISTS(SELECT 1 FROM kyc_documents d WHERE d.kyc_case_id=k.id AND d.document_kind='ID_FRONT') AS has_front,
          EXISTS(SELECT 1 FROM kyc_documents d WHERE d.kyc_case_id=k.id AND d.document_kind='ID_BACK') AS has_back,
          EXISTS(SELECT 1 FROM kyc_documents d WHERE d.kyc_case_id=k.id AND d.document_kind='SELFIE') AS has_selfie
         FROM kyc_submissions k WHERE customer_id=$1`, [customer.id],
      )
      const k = validation.rows[0]
      const required = [k.legal_first_name,k.legal_last_name,k.date_of_birth,k.nationality,k.country_of_residence,k.address,k.city,k.region,k.postal_code,k.identification_type,k.document_number_ciphertext,k.issuing_country,k.phone,k.email]
      const backRequired = k.identification_type !== "PASSPORT"
      if (required.some((v: unknown) => !v) || !k.attested || !k.has_front || !k.has_selfie || (backRequired && !k.has_back)) {
        return json({ error: "Complete all required identity fields, confirmation, and document uploads before submitting." }, 422)
      }
      if (k.expiration_date && new Date(k.expiration_date) < new Date(new Date().toISOString().slice(0,10))) return json({ error: "The identification document is expired." }, 422)
      await db.pool.query(`UPDATE kyc_submissions SET status='SUBMITTED',submitted_at=now(),updated_at=now() WHERE customer_id=$1`, [customer.id])
      return json({ kyc: await getCase(db, customer.id) }, 202)
    }
    return new Response("Method not allowed", { status: 405 })
  } catch (error) { return errorResponse(error) }
}

export const config: Config = { path: "/api/kyc" }
