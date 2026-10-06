'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import {
  LayoutDashboard, Package, Map, Truck, Users, BarChart3,
  Settings, Bell, LogOut, Box, Route, ClipboardList
} from 'lucide-react'
import type { UserRole } from '@/lib/supabase/types'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

interface NavItem {
  label: string
  href: string
  icon: React.ElementType
}

const NAV_BY_ROLE: Record<UserRole, NavItem[]> = {
  customer: [
    { label: 'Dashboard',    href: '/customer/dashboard',  icon: LayoutDashboard },
    { label: 'Shipments',   href: '/customer/shipments',  icon: Package },
    { label: 'New Shipment',href: '/customer/shipments/new', icon: Box },
    { label: 'Notifications',href: '/customer/notifications', icon: Bell },
  ],
  dispatcher: [
    { label: 'Live Map',    href: '/dispatcher/map',       icon: Map },
    { label: 'Shipments',   href: '/dispatcher/shipments', icon: Package },
    { label: 'Trip Planner',href: '/dispatcher/trips',     icon: Route },
    { label: 'Fleet',       href: '/dispatcher/fleet',     icon: Truck },
    { label: 'Hubs',        href: '/dispatcher/hubs',      icon: LayoutDashboard },
  ],
  driver: [
    { label: 'My Trips',    href: '/driver/trips',         icon: ClipboardList },
  ],
  admin: [
    { label: 'Analytics',   href: '/admin/analytics',      icon: BarChart3 },
    { label: 'Users',       href: '/admin/users',          icon: Users },
    { label: 'Audit Log',   href: '/admin/audit',          icon: ClipboardList },
    { label: 'Reports',     href: '/admin/reports',        icon: BarChart3 },
  ],
}

interface SidebarProps {
  role: UserRole
  userName: string
  userEmail: string
}

export function Sidebar({ role, userName, userEmail }: SidebarProps) {
  const pathname = usePathname()
  const router = useRouter()
  const navItems = NAV_BY_ROLE[role] ?? []

  async function handleLogout() {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push('/login')
  }

  const roleLabels: Record<UserRole, string> = {
    admin: 'Administrator',
    dispatcher: 'Dispatcher',
    driver: 'Driver',
    customer: 'Customer',
  }

  return (
    <aside className="w-64 h-screen bg-[#0D1424] border-r border-[#1F2937] flex flex-col flex-shrink-0">
      {/* Logo */}
      <div className="px-6 py-5 border-b border-[#1F2937]">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-[#FFB020] rounded-lg flex items-center justify-center">
            <Truck size={16} className="text-[#0B1020]" />
          </div>
          <div>
            <p className="text-sm font-display font-bold text-[#F4F1EA] tracking-tight">RTLTS</p>
            <p className="text-[10px] text-gray-500 uppercase tracking-widest">Logistics</p>
          </div>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        {navItems.map(item => (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              'nav-item',
              pathname.startsWith(item.href) && 'active'
            )}
          >
            <item.icon size={16} />
            <span>{item.label}</span>
          </Link>
        ))}
      </nav>

      {/* User */}
      <div className="px-3 py-4 border-t border-[#1F2937]">
        <div className="flex items-center gap-3 px-3 py-2 rounded-lg">
          <div className="w-8 h-8 rounded-full bg-[#FFB020]/20 flex items-center justify-center flex-shrink-0">
            <span className="text-xs font-bold text-[#FFB020]">
              {userName.slice(0, 2).toUpperCase()}
            </span>
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-xs font-medium text-[#F4F1EA] truncate">{userName}</p>
            <p className="text-[10px] text-gray-500 truncate">{roleLabels[role]}</p>
          </div>
        </div>
        <button
          onClick={handleLogout}
          className="w-full mt-2 nav-item text-red-400 hover:text-red-300 hover:bg-red-500/10"
        >
          <LogOut size={16} />
          <span>Sign Out</span>
        </button>
      </div>
    </aside>
  )
}
