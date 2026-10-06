import { AppShell } from '@/components/layout/AppShell'

export default function CustomerLayout({ children }: { children: React.ReactNode }) {
  // Hardcoded for demo. Middleware ensures only customers reach here.
  return (
    <AppShell role="customer" userName="Demo Customer" userEmail="customer1@rtlts.in">
      <div className="p-8">
        {children}
      </div>
    </AppShell>
  )
}
