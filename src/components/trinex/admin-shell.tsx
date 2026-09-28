"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { useState } from "react"
import { Activity, BadgeCheck, BanknoteArrowDown, BanknoteArrowUp, Bitcoin, BookOpen, BriefcaseBusiness, ChartNoAxesCombined, CreditCard, FileChartColumn, Landmark, Menu, RefreshCcw, Settings, ShieldAlert, Users, WalletCards, X } from "lucide-react"

const items=[
 ["Overview","/admin",Activity],["Customers","/admin/customers",Users],["Accounts","/admin/accounts",WalletCards],["Transactions","/admin/transactions",BookOpen],["Transfers","/admin/transfers",RefreshCcw],["Cards","/admin/cards",CreditCard],["Deposits","/admin/deposits",BanknoteArrowDown],["Withdrawals","/admin/withdrawals",BanknoteArrowUp],["KYC","/admin/kyc",BadgeCheck],["Risk","/admin/risk",ShieldAlert],["Crypto","/admin/crypto",Bitcoin],["Investments","/admin/investments",ChartNoAxesCombined],["Operations","/admin/operations",BriefcaseBusiness],["Reconciliation","/admin/reconciliation",RefreshCcw],["Audit logs","/admin/audit-logs",BookOpen],["Reports","/admin/reports",FileChartColumn],["Settings","/admin/settings",Settings]
] as const

export function AdminRouteLayout({children}:{children:React.ReactNode}){const path=usePathname();if(path==="/admin/login")return children;return <AdminShell>{children}</AdminShell>}
function AdminShell({children}:{children:React.ReactNode}){const path=usePathname(),[open,setOpen]=useState(false);return <div className="app admin-app"><div className={`mobile-overlay ${open?"open":""}`} onClick={()=>setOpen(false)}/><aside className={`sidebar ${open?"open":""}`}><Link className="brand" href="/admin"><span className="mark"><span>A</span></span><span><strong>TRINEX ADMIN</strong><small>DEVELOPMENT CONSOLE</small></span></Link><nav className="nav admin-nav"><div className="nav-label">Sandbox operations</div>{items.map(([name,url,Icon])=><Link key={url} href={url} className={path===url?"active":""} onClick={()=>setOpen(false)}><Icon size={17}/>{name}</Link>)}<div className="nav-label">Exit</div><Link href="/dashboard"><Landmark size={17}/>Customer sandbox</Link><Link href="/admin/login">Admin login</Link></nav></aside><div className="main"><header className="topbar"><button className="menu-btn" onClick={()=>setOpen(!open)} aria-label={open?"Close admin menu":"Open admin menu"}>{open?<X/>:<Menu/>}</button><span className="dev-pill">ADMIN DEVELOPMENT MODE · DEMO DATA</span></header><main className="content">{children}</main></div></div>}
