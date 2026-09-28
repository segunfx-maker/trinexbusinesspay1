import { AccountsPage, BudgetsPage, CardsPage, CryptoPage, DashboardPage, InvestmentsPage, MoneyFlowPage, NotificationsPage, SecurityPage, SettingsPage, SupportPage, TransactionsPage } from "./customer-pages"

export function FeaturePage({title}:{title:string}){
 switch(title){
  case "Dashboard": return <DashboardPage/>
  case "Accounts": return <AccountsPage/>
  case "Transactions": return <TransactionsPage/>
  case "Transfers": return <MoneyFlowPage kind="TRANSFER"/>
  case "Payments": return <MoneyFlowPage kind="PAYMENT"/>
  case "Cards": return <CardsPage/>
  case "Crypto": return <CryptoPage/>
  case "Investments": return <InvestmentsPage/>
  case "Budgets": return <BudgetsPage/>
  case "Notifications": return <NotificationsPage/>
  case "Support": return <SupportPage/>
  case "Security": return <SecurityPage/>
  case "Settings": return <SettingsPage/>
  default: return <DashboardPage/>
 }
}
