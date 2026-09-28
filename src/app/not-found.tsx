import Link from "next/link"
export default function NotFound(){return <main className="auth-panel" style={{minHeight:"100vh"}}><div className="auth-box"><span className="eyebrow">404</span><h1>Page not found</h1><p>The requested TRINEX workspace does not exist.</p><Link className="btn" href="/dashboard">Return to dashboard</Link></div></main>}
