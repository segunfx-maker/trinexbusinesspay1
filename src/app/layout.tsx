import type { Metadata } from "next"
import "./globals.css"
import "./interactive.css"

export const metadata: Metadata = { title: "TRINEX BUSINESSPAY", description: "One platform. Global finance." }
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}
