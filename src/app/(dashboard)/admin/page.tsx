import Link from "next/link"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"

export default function AdminPage() {
  return <div className="space-y-6 p-6"><h1 className="text-2xl font-semibold">Administration</h1><Card><CardHeader><CardTitle>Compliance operations</CardTitle></CardHeader><CardContent><p className="mb-4 text-muted-foreground">Review customer identity submissions through the protected compliance workflow.</p><Button render={<Link href="/admin/kyc" />}>Open KYC reviews</Button></CardContent></Card></div>
}
