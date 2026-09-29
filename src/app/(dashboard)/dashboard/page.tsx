import { DashboardCustomizer } from "@/components/dashboard/dashboard-customizer"
import { KycStatus } from "@/components/kyc/kyc-status"

export default function Page() {
  return <div className="relative"><div className="absolute right-4 top-4 z-10"><KycStatus compact /></div><DashboardCustomizer /></div>
}
