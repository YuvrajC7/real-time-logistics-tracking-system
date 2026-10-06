import { Sidebar } from './Sidebar'
import type { UserRole } from '@/lib/supabase/types'

interface AppShellProps {
  role: UserRole
  userName: string
  userEmail: string
  children: React.ReactNode
}

export function AppShell({ role, userName, userEmail, children }: AppShellProps) {
  return (
    <div className="flex h-screen overflow-hidden bg-[#0B1020]">
      <Sidebar role={role} userName={userName} userEmail={userEmail} />
      <main className="flex-1 overflow-y-auto">
        <div className="min-h-full">
          {children}
        </div>
      </main>
    </div>
  )
}
