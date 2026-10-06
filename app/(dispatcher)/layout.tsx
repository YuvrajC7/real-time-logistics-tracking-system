import { AppShell } from '@/components/layout/AppShell'

export default function DispatcherLayout({ children }: { children: React.ReactNode }) {
  return (
    <AppShell role="dispatcher" userName="Dispatcher One" userEmail="dispatch@rtlts.in">
      {children}
    </AppShell>
  )
}
