"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"

type Overview = { customer: { full_name: string }; accounts: Array<{ id:string; currency:string; status:string; internal_account_number:string|null; balance:string }>; transactions: Array<{id:string;type:string;amount:string;currency:string;status:string}>; crypto:Array<{symbol:string;name:string;available:string;reserved:string;price_usd:string|null}>; kyc:{status:string} }

export function RealOverview({ section = "overview" }: { section?: "overview" | "accounts" | "crypto" }) {
  const [data,setData] = useState<Overview|null>(null)
  const [error,setError] = useState("")
  useEffect(() => { fetch("/api/account-overview", { credentials:"include", cache:"no-store" }).then(async r => { if (r.status===401) { location.href="/sign-in"; return null } if (!r.ok) throw new Error((await r.json()).error ?? "Unable to load account data."); return r.json() }).then(value => { if (value) setData(value) }).catch(e=>setError(e.message)) }, [])
  if (error) return <div className="p-6"><p role="alert">{error}</p><Button className="mt-4" render={<Link href="/sign-in" />}>Sign in</Button></div>
  if (!data) return <div className="p-6 text-muted-foreground">Loading secure account data…</div>
  return <div className="space-y-6 p-6">
    <div><h1 className="text-2xl font-semibold">{section === "overview" ? `Welcome, ${data.customer.full_name}` : section === "accounts" ? "Currency accounts" : "Bitcoin & crypto"}</h1><p className="text-sm text-muted-foreground">KYC status: {data.kyc.status}</p></div>
    {section !== "crypto" && <div className="grid gap-4 md:grid-cols-3">{data.accounts.filter(a=>["USD","EUR","GBP"].includes(a.currency)).map(a=><Card key={a.id}><CardHeader><CardTitle>{a.currency} account</CardTitle></CardHeader><CardContent><p className="text-2xl font-semibold">{new Intl.NumberFormat(undefined,{style:"currency",currency:a.currency}).format(Number(a.balance))}</p><p className="mt-2 font-mono text-xs text-muted-foreground">{a.internal_account_number ?? "Account number pending"}</p><p className="text-xs text-muted-foreground">{a.status}</p></CardContent></Card>)}</div>}
    {section !== "accounts" && <Card><CardHeader><CardTitle>{section === "crypto" ? "Crypto balances" : "Recent ledger activity"}</CardTitle></CardHeader><CardContent className="space-y-3">{section === "crypto" ? (data.crypto.length ? data.crypto.map(c=><div key={c.symbol} className="flex justify-between border-b py-2"><span>{c.name} ({c.symbol})</span><span>{c.available}</span></div>) : <p className="text-muted-foreground">No crypto balances recorded.</p>) : (data.transactions.length ? data.transactions.map(t=><div key={t.id} className="flex justify-between border-b py-2"><span>{t.type} · {t.status}</span><span>{t.amount} {t.currency}</span></div>) : <p className="text-muted-foreground">No ledger activity recorded.</p>)}</CardContent></Card>}
  </div>
}
