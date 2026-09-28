"use client"

import Link from "next/link"
import { usePathname, useRouter } from "next/navigation"
import { useState } from "react"
import { LayoutDashboard, WalletCards, ArrowLeftRight, Send, CreditCard, Bitcoin, TrendingUp, ReceiptText, Target, Bell, LifeBuoy, ShieldCheck, Settings, Menu, X, Search, LogOut, UserCog } from "lucide-react"

const primary=[
  ["Dashboard","/dashboard",LayoutDashboard],["Accounts","/accounts",WalletCards],["Transactions","/transactions",ArrowLeftRight],
  ["Transfers","/transfers",Send],["Cards","/cards",CreditCard],["Crypto","/crypto",Bitcoin],["Investments","/investments",TrendingUp],
  ["Payments","/payments",ReceiptText],["Budgets","/budgets",Target]
] as const
const secondary=[["Notifications","/notifications",Bell],["Support","/support",LifeBuoy],["Security","/security",ShieldCheck],["Settings","/settings",Settings]] as const

export function Shell({children}:{children:React.ReactNode}){
 const path=usePathname(),router=useRouter(); const [open,setOpen]=useState(false),[notices,setNotices]=useState(false)
 const nav=(items:typeof primary|typeof secondary)=><>{items.map(([name,url,Icon])=><Link key={url} href={url} className={path===url?"active":""} onClick={()=>setOpen(false)}><Icon size={18}/><span>{name}</span></Link>)}</>
 return <div className="app">
  <div className={`mobile-overlay ${open?"open":""}`} onClick={()=>setOpen(false)}/>
  <aside className={`sidebar ${open?"open":""}`} aria-label="Main navigation">
   <Link className="brand" href="/dashboard" onClick={()=>setOpen(false)}><span className="mark"><span>T</span></span><span><strong>TRINEX BUSINESSPAY</strong><small>ONE PLATFORM. GLOBAL FINANCE.</small></span></Link>
   <nav className="nav"><div className="nav-label">Business</div>{nav(primary)}<div className="nav-label">Account</div>{nav(secondary)}<div className="nav-label">Administration</div><Link href="/admin" onClick={()=>setOpen(false)}><UserCog size={18}/>Admin portal</Link></nav>
  </aside>
  <div className="main"><header className="topbar"><button className="menu-btn" onClick={()=>setOpen(!open)} aria-label={open?"Close menu":"Open menu"}>{open?<X/>:<Menu/>}</button><div className="topbar-actions"><button className="icon-btn" onClick={()=>router.push("/transactions")} aria-label="Search transactions"><Search size={18}/></button><button className="icon-btn" onClick={()=>setNotices(!notices)} aria-label="Open notifications"><Bell size={18}/></button><button className="icon-btn" onClick={()=>router.push("/sign-in")} aria-label="Sign out"><LogOut size={18}/></button></div></header>{notices&&<div className="notification-panel"><div className="modal-head"><h3>Notifications</h3><button className="icon-btn" onClick={()=>setNotices(false)} aria-label="Close notifications"><X size={18}/></button></div><p>No new notifications. Notification delivery is not connected.</p><Link className="btn secondary" href="/notifications" onClick={()=>setNotices(false)}>View notification settings</Link></div>}<main className="content">{children}</main></div>
 </div>
}
