"use client"

import * as React from "react"
import Link from "next/link"
import { Badge } from "@/components/ui/badge"
import { ShieldCheckIcon } from "lucide-react"

const labels: Record<string, string> = {
  NOT_STARTED: "Not Verified", DRAFT: "Action Required", SUBMITTED: "Under Review",
  UNDER_REVIEW: "Under Review", APPROVED: "Approved", REJECTED: "Action Required", EXPIRED: "Action Required",
}

export function KycStatus({ compact = false }: { compact?: boolean }) {
  const [status, setStatus] = React.useState<string>("NOT_STARTED")
  React.useEffect(() => { fetch("/api/kyc", { credentials: "include" }).then(r => r.ok ? r.json() : null).then(v => v?.kyc?.status && setStatus(v.kyc.status)).catch(() => undefined) }, [])
  return (
    <Link href="/settings/kyc" className={compact ? "inline-flex" : "block"}>
      <div className="flex items-center gap-2 rounded-full border bg-card px-3 py-1.5 text-sm shadow-sm transition hover:border-primary/50">
        <ShieldCheckIcon className="size-4 text-primary" />
        <span className="font-medium">KYC: {labels[status] ?? "Not Verified"}</span>
        {!compact && <Badge variant={status === "APPROVED" ? "default" : "secondary"}>{status.replaceAll("_", " ")}</Badge>}
      </div>
    </Link>
  )
}
