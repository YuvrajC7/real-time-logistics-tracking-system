'use client'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { Truck, Eye, EyeOff, ArrowRight } from 'lucide-react'
import { loginSchema, type LoginForm } from '@/lib/schemas/auth.schema'
import { createClient } from '@/lib/supabase/client'

export default function LoginPage() {
  const router = useRouter()
  const [showPw, setShowPw] = useState(false)
  const [loading, setLoading] = useState(false)

  const { register, handleSubmit, formState: { errors } } = useForm<LoginForm>({
    resolver: zodResolver(loginSchema),
  })

  async function onSubmit(data: LoginForm) {
    setLoading(true)
    try {
      const supabase = createClient()
      const { error } = await supabase.auth.signInWithPassword({
        email: data.email,
        password: data.password,
      })
      if (error) throw error
      // Middleware will redirect based on role
      router.refresh()
      router.push('/')
    } catch (e: unknown) {
      toast.error((e as Error).message || 'Login failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-[#0B1020] flex">
      {/* Left panel */}
      <div className="hidden lg:flex lg:w-1/2 bg-[#0D1424] border-r border-[#1F2937] flex-col p-12 relative overflow-hidden">
        <div className="absolute inset-0 bg-grid opacity-40" />
        <div className="relative">
          <div className="flex items-center gap-3 mb-16">
            <div className="w-10 h-10 bg-[#FFB020] rounded-xl flex items-center justify-center">
              <Truck size={20} className="text-[#0B1020]" />
            </div>
            <span className="font-display font-bold text-xl text-[#F4F1EA]">RTLTS</span>
          </div>
          <h1 className="font-display text-4xl font-bold text-[#F4F1EA] leading-tight mb-4">
            Control tower<br />for modern logistics.
          </h1>
          <p className="text-gray-400 text-lg leading-relaxed">
            Track every parcel. Monitor every vehicle. Deliver on time, every time.
          </p>

          <div className="mt-16 space-y-4">
            {[
              { label: 'Live vehicle tracking', value: 'Under 1s latency' },
              { label: 'Shipments managed', value: '120,000+' },
              { label: 'On-time delivery rate', value: '96.4%' },
            ].map(stat => (
              <div key={stat.label} className="flex items-center justify-between py-3 border-b border-[#1F2937]">
                <span className="text-sm text-gray-400">{stat.label}</span>
                <span className="text-sm font-mono font-bold text-[#FFB020]">{stat.value}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Right panel */}
      <div className="flex-1 flex items-center justify-center p-8">
        <div className="w-full max-w-md">
          <div className="lg:hidden flex items-center gap-3 mb-8">
            <div className="w-8 h-8 bg-[#FFB020] rounded-lg flex items-center justify-center">
              <Truck size={16} className="text-[#0B1020]" />
            </div>
            <span className="font-display font-bold text-lg text-[#F4F1EA]">RTLTS</span>
          </div>

          <h2 className="font-display text-2xl font-bold text-[#F4F1EA] mb-1">Welcome back</h2>
          <p className="text-gray-400 text-sm mb-8">Sign in to your logistics console.</p>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1.5">Email</label>
              <input
                {...register('email')}
                type="email"
                className="input-base"
                placeholder="you@company.com"
                autoComplete="email"
              />
              {errors.email && <p className="text-xs text-red-400 mt-1">{errors.email.message}</p>}
            </div>

            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="text-sm font-medium text-gray-300">Password</label>
                <Link href="/reset" className="text-xs text-[#FFB020] hover:underline">Forgot password?</Link>
              </div>
              <div className="relative">
                <input
                  {...register('password')}
                  type={showPw ? 'text' : 'password'}
                  className="input-base pr-10"
                  placeholder="••••••••"
                  autoComplete="current-password"
                />
                <button
                  type="button"
                  onClick={() => setShowPw(!showPw)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300"
                >
                  {showPw ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
              {errors.password && <p className="text-xs text-red-400 mt-1">{errors.password.message}</p>}
            </div>

            <button
              type="submit"
              disabled={loading}
              className="btn-primary w-full"
            >
              {loading ? 'Signing in...' : 'Sign in'}
              {!loading && <ArrowRight size={16} />}
            </button>
          </form>

          <p className="text-center text-sm text-gray-500 mt-6">
            New customer?{' '}
            <Link href="/signup" className="text-[#FFB020] hover:underline">Create an account</Link>
          </p>

          {/* Demo credentials */}
          <div className="mt-8 p-4 bg-[#111827] border border-[#1F2937] rounded-xl">
            <p className="text-xs font-semibold text-gray-400 mb-3 uppercase tracking-wider">Demo accounts</p>
            <div className="space-y-2">
              {[
                { role: 'Admin',      email: 'admin@rtlts.in',      pw: 'Admin@123' },
                { role: 'Dispatcher', email: 'dispatch@rtlts.in',   pw: 'Dispatch@123' },
                { role: 'Driver',     email: 'driver1@rtlts.in',    pw: 'Driver@123' },
                { role: 'Customer',   email: 'customer1@rtlts.in',  pw: 'Customer@123' },
              ].map(d => (
                <div key={d.role} className="flex items-center justify-between">
                  <span className="text-xs text-gray-500">{d.role}</span>
                  <span className="text-xs font-mono text-gray-400">{d.email}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
