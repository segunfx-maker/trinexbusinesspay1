import { LandmarkIcon, ShieldAlertIcon } from "lucide-react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

export function ServiceUnavailable({ area }: { area: string }) {
  return (
    <div className="flex flex-1 items-center justify-center p-4 md:p-8">
      <Card className="w-full max-w-3xl overflow-hidden border-primary/20 bg-card/80 shadow-2xl shadow-black/30">
        <div className="h-px bg-gradient-to-r from-transparent via-primary to-transparent" />
        <CardHeader className="space-y-5 p-8 md:p-12">
          <div className="flex size-12 items-center justify-center rounded-xl border border-primary/30 bg-primary/10 text-primary">
            <LandmarkIcon className="size-5" />
          </div>
          <div className="space-y-2">
            <p className="text-xs font-semibold tracking-[0.24em] text-primary">TRINEX BUSINESSPAY</p>
            <CardTitle className="text-2xl tracking-tight md:text-4xl">{area} is not connected</CardTitle>
            <p className="max-w-xl text-sm leading-6 text-muted-foreground md:text-base">
              No customer, balance, transaction, or financial activity is available. Connect an approved backend service before using this area.
            </p>
          </div>
        </CardHeader>
        <CardContent className="flex items-center gap-2 border-t border-border/60 bg-muted/20 px-8 py-5 text-xs text-muted-foreground md:px-12">
          <ShieldAlertIcon className="size-4 text-primary" />
          <span>ONE PLATFORM. GLOBAL FINANCE.</span>
        </CardContent>
      </Card>
    </div>
  )
}
