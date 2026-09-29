import { createHash, randomUUID } from "node:crypto"
import { getStore } from "@netlify/blobs"
import type { Config, Context } from "@netlify/functions"
import { canAccessKycDocument, errorResponse, json, requireIdentity } from "./_shared/kyc.mts"
import { getDatabase } from "@netlify/database"

const MAX_BYTES = 5 * 1024 * 1024
const ALLOWED = new Set(["image/jpeg", "image/png", "application/pdf"])
const KINDS = new Set(["ID_FRONT", "ID_BACK", "SELFIE"])
const store = () => getStore({ name: "private-kyc-documents", consistency: "strong" })

function detectedContentType(bytes: ArrayBuffer) {
  const b = new Uint8Array(bytes)
  if (b.length >= 4 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return "image/jpeg"
  if (b.length >= 8 && b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47 && b[4] === 0x0d && b[5] === 0x0a && b[6] === 0x1a && b[7] === 0x0a) return "image/png"
  if (b.length >= 5 && new TextDecoder().decode(b.slice(0, 5)) === "%PDF-") return "application/pdf"
  return null
}

async function actorContext(identityId: string) {
  const db = getDatabase()
  const [customerResult, adminResult] = await Promise.all([
    db.pool.query(`SELECT id FROM users WHERE identity_id=$1 OR EXISTS (SELECT 1 FROM customer_auth_identities c WHERE c.customer_id=users.id AND c.provider_subject=$1) LIMIT 1`, [identityId]),
    db.pool.query(`SELECT role FROM admin_identities WHERE identity_id=$1 AND active=true LIMIT 1`, [identityId]),
  ])
  return { db, customerId: customerResult.rows[0]?.id as string | undefined, role: adminResult.rows[0]?.role as string | undefined }
}

export default async (req: Request, context: Context) => {
  try {
    const identity = await requireIdentity()
    const actor = await actorContext(identity.id)
    if (req.method === "POST") {
      if (!actor.customerId) return json({ error: "Customer account required." }, 403)
      const form = await req.formData()
      const file = form.get("file")
      const kind = String(form.get("kind") ?? "")
      if (!(file instanceof File) || !KINDS.has(kind)) return json({ error: "A valid document and document kind are required." }, 422)
      if (!ALLOWED.has(file.type)) return json({ error: "Only JPG, JPEG, PNG, and PDF documents are accepted." }, 415)
      if (file.size < 1 || file.size > MAX_BYTES) return json({ error: "Documents must be no larger than 5 MB." }, 413)
      const caseResult = await actor.db.pool.query(`SELECT id,status,resubmission_permitted FROM kyc_submissions WHERE customer_id=$1`, [actor.customerId])
      const kyc = caseResult.rows[0]
      if (!kyc || !["NOT_STARTED","DRAFT","REJECTED","EXPIRED"].includes(kyc.status) || (kyc.status === "REJECTED" && !kyc.resubmission_permitted)) {
        return json({ error: "Documents cannot be changed while this case is being reviewed." }, 409)
      }
      const bytes = await file.arrayBuffer()
      const verifiedType = detectedContentType(bytes)
      if (!verifiedType || verifiedType !== file.type) return json({ error: "The file content does not match an accepted JPG, PNG, or PDF format." }, 415)
      const key = `${actor.customerId}/${kyc.id}/${randomUUID()}`
      await store().set(key, bytes)
      const sha256 = createHash("sha256").update(Buffer.from(bytes)).digest("hex")
      const prior = await actor.db.pool.query(`SELECT blob_key FROM kyc_documents WHERE kyc_case_id=$1 AND document_kind=$2`, [kyc.id, kind])
      await actor.db.pool.query(
        `INSERT INTO kyc_documents(kyc_case_id,customer_id,document_kind,blob_key,content_type,byte_size,sha256,original_filename)
         VALUES($1,$2,$3,$4,$5,$6,$7,$8)
         ON CONFLICT(kyc_case_id,document_kind) DO UPDATE SET blob_key=EXCLUDED.blob_key,content_type=EXCLUDED.content_type,
           byte_size=EXCLUDED.byte_size,sha256=EXCLUDED.sha256,original_filename=EXCLUDED.original_filename,updated_at=now()`,
        [kyc.id, actor.customerId, kind, key, file.type, file.size, sha256, file.name.slice(0,180)],
      )
      if (prior.rows[0]?.blob_key) await store().delete(prior.rows[0].blob_key)
      await actor.db.pool.query(`UPDATE kyc_submissions SET status='DRAFT',updated_at=now() WHERE id=$1`, [kyc.id])
      return json({ uploaded: true, kind }, 201)
    }
    if (req.method === "GET") {
      const documentId = context.params.id
      if (!documentId) return json({ error: "Document ID required." }, 400)
      const result = await actor.db.pool.query(
        `SELECT d.*,k.customer_id AS case_customer_id FROM kyc_documents d JOIN kyc_submissions k ON k.id=d.kyc_case_id WHERE d.id=$1`,
        [documentId],
      )
      const doc = result.rows[0]
      if (!doc) return json({ error: "Document not found." }, 404)
      const adminAllowed = canAccessKycDocument(undefined, actor.role, doc.customer_id)
      if (!canAccessKycDocument(actor.customerId, actor.role, doc.customer_id)) return json({ error: "You are not authorized to access this document." }, 403)
      await actor.db.pool.query(
        `INSERT INTO kyc_document_access_log(document_id,kyc_case_id,customer_id,actor_identity_id,actor_role,reason)
         VALUES($1,$2,$3,$4,$5,$6)`,
        [doc.id, doc.kyc_case_id, doc.customer_id, identity.id, adminAllowed ? actor.role : "CUSTOMER", adminAllowed ? "Compliance case review" : "Customer viewed own document"],
      )
      const bytes = await store().get(doc.blob_key, { type: "arrayBuffer" })
      if (!bytes) return json({ error: "Document content is unavailable." }, 404)
      return new Response(bytes as ArrayBuffer, {
        headers: {
          "Content-Type": doc.content_type,
          "Content-Disposition": `inline; filename="kyc-document.${doc.content_type === "application/pdf" ? "pdf" : doc.content_type === "image/png" ? "png" : "jpg"}"`,
          "Cache-Control": "private, no-store, max-age=0",
          "X-Content-Type-Options": "nosniff",
        },
      })
    }
    return new Response("Method not allowed", { status: 405 })
  } catch (error) { return errorResponse(error) }
}

export const config: Config = { path: ["/api/kyc/documents", "/api/kyc/documents/:id"] }
