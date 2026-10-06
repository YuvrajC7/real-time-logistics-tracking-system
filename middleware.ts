import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'
import type { UserRole } from '@/lib/supabase/types'

const ROLE_HOME: Record<UserRole, string> = {
  admin:      '/admin/analytics',
  dispatcher: '/dispatcher/map',
  driver:     '/driver/trips',
  customer:   '/customer/dashboard',
}

const PROTECTED_PREFIXES: Record<string, UserRole[]> = {
  '/admin':      ['admin'],
  '/dispatcher': ['admin', 'dispatcher'],
  '/driver':     ['admin', 'driver'],
  '/customer':   ['admin', 'customer'],
}

export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return request.cookies.getAll() },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  const { data: { user } } = await supabase.auth.getUser()
  const pathname = request.nextUrl.pathname

  // Redirect logged-in users away from auth pages
  if (user && ['/login', '/signup', '/reset'].includes(pathname)) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('profile_id', user.id)
      .single()
    const role = profile?.role ?? 'customer'
    return NextResponse.redirect(new URL(ROLE_HOME[role as UserRole], request.url))
  }

  // Protect role-specific routes
  for (const [prefix, allowedRoles] of Object.entries(PROTECTED_PREFIXES)) {
    if (pathname.startsWith(prefix)) {
      if (!user) {
        return NextResponse.redirect(new URL(`/login?redirect=${encodeURIComponent(pathname)}`, request.url))
      }
      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
        .eq('profile_id', user.id)
        .single()
      const role = profile?.role as UserRole
      if (!allowedRoles.includes(role)) {
        return NextResponse.redirect(new URL(ROLE_HOME[role] ?? '/', request.url))
      }
      break
    }
  }

  return supabaseResponse
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
