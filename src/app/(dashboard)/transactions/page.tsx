import { ServiceUnavailable } from "@/components/service-unavailable"

export default function Page() {
  return (
    <div className="flex flex-1 flex-col gap-4 p-4 pt-0">
      <ServiceUnavailable area="Transactions" />
    </div>
  )
}
