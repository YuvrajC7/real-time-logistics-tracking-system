import { AppShell } from '@/components/layout/AppShell'

export default function DriverLayout({ children }: { children: React.ReactNode }) {
  return (
    <AppShell role="driver" userName="Driver One" userEmail="driver1@rtlts.in">
      <div className="p-4 md:p-8 max-w-lg mx-auto">
        {children}
      </div>
    </AppShell>
  )
}
