"use client"

import * as React from "react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { CheckCircle2Icon, FileLock2Icon, LoaderIcon, ShieldCheckIcon, UploadCloudIcon } from "lucide-react"

type Document = { id: string; kind: string; contentType: string; size: number }
type Kyc = Record<string, string | boolean | null | Document[]> & { status: string; documents: Document[]; resubmission_permitted: boolean }
const fieldClass = "space-y-1.5"
const selectClass = "h-9 w-full rounded-md border bg-transparent px-3 text-sm outline-none focus:ring-2 focus:ring-ring"

export function CustomerKyc() {
  const [kyc, setKyc] = React.useState<Kyc | null>(null)
  const [form, setForm] = React.useState<Record<string, string | boolean>>({ attested: false })
  const [busy, setBusy] = React.useState(false)
  const [message, setMessage] = React.useState("")
  const editable = !kyc || ["NOT_STARTED", "DRAFT", "REJECTED", "EXPIRED"].includes(kyc.status)

  const load = React.useCallback(async () => {
    const response = await fetch("/api/kyc", { credentials: "include" })
    const body = await response.json()
    if (!response.ok) throw new Error(body.error)
    setKyc(body.kyc)
    const scalarFields = Object.fromEntries(
      Object.entries(body.kyc as Record<string, unknown>).filter((entry): entry is [string, string | boolean] => typeof entry[1] === "string" || typeof entry[1] === "boolean"),
    )
    setForm(prev => ({ ...prev, ...scalarFields }))
  }, [])
  React.useEffect(() => { load().catch(e => setMessage(e.message)) }, [load])
  const change = (name: string, value: string | boolean) => setForm(f => ({ ...f, [name]: value }))

  async function save() {
    setBusy(true); setMessage("")
    try {
      const response = await fetch("/api/kyc", { method: "PUT", credentials: "include", headers: { "Content-Type": "application/json" }, body: JSON.stringify(form) })
      const body = await response.json(); if (!response.ok) throw new Error(body.error)
      setKyc(body.kyc); setMessage("Draft saved securely.")
    } catch (e) { setMessage(e instanceof Error ? e.message : "Unable to save.") } finally { setBusy(false) }
  }
  async function upload(kind: string, file?: File) {
    if (!file) return
    setBusy(true); setMessage("")
    try {
      const data = new FormData(); data.set("kind", kind); data.set("file", file)
      const response = await fetch("/api/kyc/documents", { method: "POST", credentials: "include", body: data })
      const body = await response.json(); if (!response.ok) throw new Error(body.error)
      await load(); setMessage("Document uploaded to private storage.")
    } catch (e) { setMessage(e instanceof Error ? e.message : "Upload failed.") } finally { setBusy(false) }
  }
  async function submit() {
    setBusy(true); setMessage("")
    try {
      await save()
      const response = await fetch("/api/kyc", { method: "POST", credentials: "include" })
      const body = await response.json(); if (!response.ok) throw new Error(body.error)
      setKyc(body.kyc); setMessage("KYC submitted for manual review.")
    } catch (e) { setMessage(e instanceof Error ? e.message : "Submission failed.") } finally { setBusy(false) }
  }
  if (!kyc) return <div className="flex min-h-56 items-center justify-center"><LoaderIcon className="size-5 animate-spin" /></div>
  const statusTone = kyc.status === "APPROVED" ? "text-emerald-700 dark:text-emerald-300" : kyc.status === "REJECTED" || kyc.status === "EXPIRED" ? "text-destructive" : "text-primary"
  const inputs = [
    ["legalFirstName","Legal first name","text",true],["legalMiddleName","Legal middle name","text",false],["legalLastName","Legal last name","text",true],
    ["dateOfBirth","Date of birth","date",true],["nationality","Nationality","text",true],["countryOfResidence","Country of residence","text",true],
    ["address","Residential address","text",true],["city","City","text",true],["region","State / Province / Region","text",true],
    ["postalCode","Postal / ZIP code","text",true],["phone","Phone number","tel",true],["email","Email address","email",true],
    ["documentNumber","ID document number","text",true],["issuingCountry","ID issuing country","text",true],["issueDate","ID issue date","date",false],
    ["expirationDate","ID expiration date","date",false],
  ] as const
  return (
    <div className="mx-auto w-full max-w-6xl space-y-6 p-4 md:p-6">
      <section className="overflow-hidden rounded-3xl border bg-[linear-gradient(135deg,var(--card),var(--accent))] p-6 md:p-8">
        <div className="flex flex-col justify-between gap-5 md:flex-row md:items-end">
          <div className="max-w-2xl"><div className="mb-4 flex size-11 items-center justify-center rounded-2xl bg-primary text-primary-foreground"><ShieldCheckIcon /></div><p className="text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">Identity assurance</p><h1 className="mt-2 text-3xl font-semibold tracking-tight">Manual KYC verification</h1><p className="mt-2 text-sm text-muted-foreground">Your documents stay private and are available only to you and authorized compliance reviewers.</p></div>
          <div className="rounded-2xl border bg-background/80 p-4 backdrop-blur"><p className="text-xs text-muted-foreground">Current status</p><p className={`mt-1 text-lg font-semibold ${statusTone}`}>{kyc.status.replaceAll("_", " ")}</p>{kyc.submitted_at && <p className="mt-1 text-xs text-muted-foreground">Submitted {new Date(String(kyc.submitted_at)).toLocaleDateString()}</p>}</div>
        </div>
      </section>
      {(kyc.decision_reason || kyc.correction_details) && <Card className="border-destructive/30"><CardHeader><CardTitle className="text-base">Action required</CardTitle><CardDescription>{String(kyc.decision_reason ?? "Please update your submission.")}</CardDescription></CardHeader>{kyc.correction_details && <CardContent className="text-sm">Correct: {String(kyc.correction_details)}</CardContent>}</Card>}
      <fieldset disabled={!editable || busy} className="space-y-6 disabled:opacity-75">
        <Card><CardHeader><CardTitle>Identity information</CardTitle><CardDescription>Enter details exactly as they appear on your identification.</CardDescription></CardHeader><CardContent className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {inputs.map(([name,label,type,required]) => <label key={name} className={fieldClass}><span className="text-sm font-medium">{label}{required && " *"}</span><Input type={type} required={required} value={String(form[name] ?? "")} onChange={e => change(name,e.target.value)} /></label>)}
          <label className={fieldClass}><span className="text-sm font-medium">ID document type *</span><select className={selectClass} value={String(form.documentType ?? "")} onChange={e => change("documentType",e.target.value)}><option value="">Select a document</option><option value="PASSPORT">Passport</option><option value="NATIONAL_ID">National ID</option><option value="DRIVERS_LICENSE">Driver&apos;s License</option><option value="GOVERNMENT_ID">Government-issued ID</option></select></label>
        </CardContent></Card>
        <Card><CardHeader><CardTitle>Private documents</CardTitle><CardDescription>JPG, JPEG, PNG, or PDF. Maximum 5 MB each. Files never receive public URLs.</CardDescription></CardHeader><CardContent className="grid gap-4 md:grid-cols-3">{[["ID_FRONT","Front of ID"],["ID_BACK","Back of ID"],["SELFIE","Identity selfie"]].map(([kind,label]) => { const present=kyc.documents?.find(d=>d.kind===kind); return <label key={kind} className="group flex min-h-40 cursor-pointer flex-col items-center justify-center rounded-2xl border border-dashed p-5 text-center transition hover:border-primary hover:bg-accent/40"><input className="sr-only" type="file" accept="image/jpeg,image/png,application/pdf" onChange={e=>upload(kind,e.target.files?.[0])}/>{present ? <CheckCircle2Icon className="size-7 text-emerald-600"/>:<UploadCloudIcon className="size-7 text-muted-foreground"/>}<span className="mt-3 text-sm font-semibold">{label}</span><span className="mt-1 text-xs text-muted-foreground">{present ? `${Math.ceil(present.size/1024)} KB uploaded` : "Choose file or use camera"}</span></label>})}</CardContent></Card>
        <Card><CardContent className="pt-6"><label className="flex items-start gap-3"><input className="mt-1 size-4 accent-[var(--primary)]" type="checkbox" checked={Boolean(form.attested)} onChange={e=>change("attested",e.target.checked)}/><span className="text-sm font-medium">I confirm that the information provided is accurate and belongs to me.</span></label><div className="mt-5 flex flex-wrap items-center justify-between gap-3"><div className="flex items-center gap-2 text-xs text-muted-foreground"><FileLock2Icon className="size-4"/>Encrypted data and restricted document access</div><div className="flex gap-2"><Button variant="outline" onClick={save} type="button">Save draft</Button><Button onClick={submit} type="button">Submit for review</Button></div></div>{message && <p role="status" className="mt-4 text-sm">{message}</p>}</CardContent></Card>
      </fieldset>
      {!editable && <p className="text-center text-sm text-muted-foreground">Editing is locked while compliance reviews this submission.</p>}
    </div>
  )
}
