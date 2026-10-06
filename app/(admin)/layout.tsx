import { AppShell } from '@/components/layout/AppShell'

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <AppShell role="admin" userName="System Admin" userEmail="admin@rtlts.in">
      <div className="p-8">
        {children}
      </div>
    </AppShell>
  )
}
